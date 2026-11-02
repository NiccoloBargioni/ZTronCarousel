'use strict';

const { contextBridge, ipcRenderer, webUtils } = require('electron');

contextBridge.exposeInMainWorld('calibrator', {
  openImage: () => ipcRenderer.invoke('open-image'),
  openOutline: () => ipcRenderer.invoke('open-outline'),
  readImage: (filePath) => ipcRenderer.invoke('read-image', filePath),
  readOutline: (filePath) => ipcRenderer.invoke('read-outline', filePath),
  findOutline: (imagePath) => ipcRenderer.invoke('find-outline', imagePath),
  pathForFile: (file) => webUtils.getPathForFile(file),
  log: (line) => ipcRenderer.send('log', line),
  onMenuCommand: (callback) => ipcRenderer.on('menu-command', (_event, command) => callback(command)),
});
