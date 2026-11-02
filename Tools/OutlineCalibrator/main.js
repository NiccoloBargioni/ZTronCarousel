'use strict';

const { app, BrowserWindow, Menu, dialog, ipcMain } = require('electron');
const { execFile } = require('node:child_process');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { promisify } = require('node:util');

const execFileAsync = promisify(execFile);

const IMAGE_MIME = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
};
const HEIC_EXTENSIONS = new Set(['.heic', '.heif']);
const OUTLINE_SEARCH_ENTRY_LIMIT = 50000;
const OUTLINE_SEARCH_SKIPPED_DIRECTORIES = new Set(['node_modules', 'DerivedData', 'Pods']);

let mainWindow = null;

/** Chromium cannot decode HEIC, so it goes through macOS' `sips` first. */
async function readImage(filePath) {
  const extension = path.extname(filePath).toLowerCase();
  const name = path.basename(filePath);

  if (IMAGE_MIME[extension]) {
    return { name, path: filePath, mime: IMAGE_MIME[extension], bytes: await fs.readFile(filePath), orientation: 1 };
  }

  if (!HEIC_EXTENSIONS.has(extension)) {
    throw new Error(`Unsupported image type "${extension}". Use .heic, .png, .jpg or .jpeg.`);
  }
  if (process.platform !== 'darwin') {
    throw new Error('HEIC images are decoded with macOS sips. Convert the image to PNG on this platform.');
  }

  const { stdout } = await execFileAsync('/usr/bin/sips', ['-g', 'orientation', filePath]);
  const orientationMatch = /orientation:\s*(\d+)/.exec(stdout);

  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'outline-calibrator-'));
  try {
    const converted = path.join(directory, 'image.png');
    await execFileAsync('/usr/bin/sips', ['-s', 'format', 'png', filePath, '--out', converted]);
    return {
      name,
      path: filePath,
      mime: 'image/png',
      bytes: await fs.readFile(converted),
      orientation: orientationMatch ? Number(orientationMatch[1]) : 1,
    };
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
}

async function readOutline(filePath) {
  return { name: path.basename(filePath), path: filePath, text: await fs.readFile(filePath, 'utf8') };
}

/**
 * Looks for `<image name>.svg` anywhere under the image's directory, breadth-first so the shallowest
 * match wins (ties broken alphabetically by path). Hidden and build directories are skipped and
 * symlinked directories are not followed.
 */
async function findCompanionOutline(imagePath) {
  const root = path.dirname(imagePath);
  const imageName = path.parse(imagePath).name;
  let level = [root];
  let visited = 0;

  while (level.length > 0) {
    const matches = [];
    const next = [];
    for (const directory of level) {
      let entries;
      try {
        entries = await fs.readdir(directory, { withFileTypes: true });
      } catch {
        continue; // unreadable directory
      }
      visited += entries.length;
      for (const entry of entries) {
        const parsed = path.parse(entry.name);
        if ((entry.isFile() || entry.isSymbolicLink()) && parsed.name === imageName && parsed.ext.toLowerCase() === '.svg') {
          matches.push(path.join(directory, entry.name));
        } else if (entry.isDirectory() && !entry.name.startsWith('.') && !OUTLINE_SEARCH_SKIPPED_DIRECTORIES.has(entry.name)) {
          next.push(path.join(directory, entry.name));
        }
      }
      if (visited > OUTLINE_SEARCH_ENTRY_LIMIT) return { root, truncated: true };
    }
    if (matches.length > 0) {
      matches.sort();
      const outline = await readOutline(matches[0]);
      return { ...outline, root, relativePath: path.relative(root, matches[0]), alternatives: matches.length - 1 };
    }
    level = next.sort();
  }
  return { root, truncated: false };
}

async function pick(kind) {
  const filters = kind === 'image'
    ? [{ name: 'Images', extensions: ['heic', 'heif', 'png', 'jpg', 'jpeg'] }]
    : [{ name: 'SVG outline', extensions: ['svg'] }];
  const result = await dialog.showOpenDialog(mainWindow, {
    title: kind === 'image' ? 'Choose an image' : 'Choose an outline SVG',
    properties: ['openFile'],
    filters,
  });
  return result.canceled ? null : result.filePaths[0];
}

ipcMain.handle('open-image', async () => {
  const filePath = await pick('image');
  return filePath ? readImage(filePath) : null;
});
ipcMain.handle('open-outline', async () => {
  const filePath = await pick('outline');
  return filePath ? readOutline(filePath) : null;
});
ipcMain.handle('read-image', (_event, filePath) => readImage(filePath));
ipcMain.handle('read-outline', (_event, filePath) => readOutline(filePath));
ipcMain.handle('find-outline', (_event, imagePath) => findCompanionOutline(imagePath));
ipcMain.on('log', (_event, line) => console.log(line));

function sendMenuCommand(command) {
  mainWindow?.webContents.send('menu-command', command);
}

function buildMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    ...(isMac ? [{ role: 'appMenu' }] : []),
    {
      label: 'File',
      submenu: [
        { label: 'Open Image…', accelerator: 'CmdOrCtrl+O', click: () => sendMenuCommand('open-image') },
        { label: 'Open Outline SVG…', accelerator: 'CmdOrCtrl+Shift+O', click: () => sendMenuCommand('open-outline') },
        { type: 'separator' },
        isMac ? { role: 'close' } : { role: 'quit' },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        // Text-field undo; the page intercepts ⌘Z itself for box history when no field is focused.
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'selectAll' },
      ],
    },
    {
      label: 'View',
      submenu: [
        { label: 'Actual Size', accelerator: 'CmdOrCtrl+0', click: () => sendMenuCommand('zoom-reset') },
        { label: 'Zoom In', accelerator: 'CmdOrCtrl+=', click: () => sendMenuCommand('zoom-in') },
        { label: 'Zoom Out', accelerator: 'CmdOrCtrl+-', click: () => sendMenuCommand('zoom-out') },
        { type: 'separator' },
        { role: 'reload' },
        { role: 'toggleDevTools' },
        { role: 'togglefullscreen' },
      ],
    },
    { role: 'windowMenu' },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1440,
    height: 940,
    minWidth: 900,
    minHeight: 600,
    title: 'Outline Calibrator',
    backgroundColor: '#111214',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  buildMenu();
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
