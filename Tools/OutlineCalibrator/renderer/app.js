(() => {
  'use strict';

  const S = window.SwiftSVG;
  const bridge = window.calibrator || null; // absent when the page is opened in a plain browser
  const SVG_NS = 'http://www.w3.org/2000/svg';

  const STORAGE_KEY = 'outline-calibrator/v1';
  const CAROUSEL_ASPECT_RATIO = 16 / 9;
  const PAGE_PADDING = 28;
  const ZOOM_MIN = 0.5;
  const ZOOM_MAX = 40;
  const MIN_BOX_SIZE = 1e-4; // normalized
  const THUMB_SIZE = 9;
  const THUMB_HIT_SIZE = 20;
  const HANDLES = {
    nw: [0, 0], n: [0.5, 0], ne: [1, 0], e: [1, 0.5],
    se: [1, 1], s: [0.5, 1], sw: [0, 1], w: [0, 0.5],
  };
  const CURSORS = {
    nw: 'nwse-resize', se: 'nwse-resize', ne: 'nesw-resize', sw: 'nesw-resize',
    n: 'ns-resize', s: 'ns-resize', e: 'ew-resize', w: 'ew-resize',
  };

  const $ = (id) => document.getElementById(id);
  const el = {
    viewport: $('viewport'), overlay: $('overlay'), world: $('world'),
    pageBackground: $('page-background'), photo: $('photo'), outline: $('outline'),
    outsideMask: $('outside-mask'), pageFrame: $('page-frame'), containerFrame: $('container-frame'),
    outlineHit: $('outline-hit'), aabb: $('aabb'), thumbs: $('thumbs'),
    emptyHint: $('empty-hint'), zoomLabel: $('zoom-label'),
    imageName: $('image-name'), imageInfo: $('image-info'),
    outlineName: $('outline-name'), outlineInfo: $('outline-info'),
    inputs: { x: $('input-x'), y: $('input-y'), width: $('input-width'), height: $('input-height') },
    pasteBox: $('paste-box'), undo: $('undo'), redo: $('redo'), fitBox: $('fit-box'),
    pixelUnits: $('pixel-units'), boxTitle: $('box-title'), unitsHint: $('units-hint'), pasteStatus: $('paste-status'),
    color: $('input-color'), opacity: $('input-opacity'), showBox: $('show-box'),
    renderInfo: $('render-info'), notesSection: $('notes-section'), notes: $('notes'),
    readout: $('readout-text'), log: $('log'),
    fileImage: $('file-image'), fileOutline: $('file-outline'),
  };

  const state = {
    box: { x: 0.4, y: 0.4, width: 0.2, height: 0.2 },
    image: null, // { name, url, width, height, orientation }
    outline: null, // { name, model, paths }
    color: '#ffd60a',
    opacity: 1,
    showBox: true,
    pixelUnits: false, // edit the box in pixels of referenceSize instead of normalized units
    referenceSize: null, // { width, height, source: 'paste' | 'image' }: last pasted denominators or loaded image
    view: { zoom: 1, panX: 0, panY: 0 },
    error: null,
  };
  const history = { entries: [], index: -1 };
  const thumbs = {};
  let geometry = null;
  let drag = null;
  let spaceHeld = false;
  let renderQueued = false;
  let nudgeCommitTimer = null;

  // -------------------------------------------------------------------------------------------
  // Formatting

  const fmt = (value) => value.toFixed(6);
  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
  const sameBox = (a, b) => a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
  const imageResolution = () => (state.image ? `${state.image.width} × ${state.image.height}` : '—');
  const fmtPixels = (value) => String(+value.toFixed(2));

  // -------------------------------------------------------------------------------------------
  // Pixel units

  /**
   * The pixel size of the box the carousel normalizes an image against: the image itself when it is
   * 16:9, otherwise the 16:9 frame anchored at its top-left corner (see computeGeometry).
   */
  function imageReferenceSize(image) {
    if (image.width * 9 === image.height * 16) return { width: image.width, height: image.height };
    return {
      width: Math.max(image.width, (image.height * 16) / 9),
      height: Math.max(image.height, (image.width * 9) / 16),
    };
  }

  /** What pixel values are divided by: the denominators of the last paste, or the last loaded image. */
  const pixelReference = () => state.referenceSize;
  const pixelMode = () => state.pixelUnits && pixelReference() !== null;
  const dimensionFor = (key, reference) => (key === 'x' || key === 'width' ? reference.width : reference.height);

  // -------------------------------------------------------------------------------------------
  // Persistence (per-viewer convenience only)

  function restore() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
      if (!saved) return;
      if (saved.box && ['x', 'y', 'width', 'height'].every((k) => Number.isFinite(saved.box[k]))) state.box = clampBox(saved.box);
      if (typeof saved.color === 'string') state.color = saved.color;
      if (Number.isFinite(saved.opacity)) state.opacity = clamp(saved.opacity, 0, 1);
      if (typeof saved.showBox === 'boolean') state.showBox = saved.showBox;
      if (typeof saved.pixelUnits === 'boolean') state.pixelUnits = saved.pixelUnits;
      const size = saved.pastedSize;
      if (size && Number.isFinite(size.width) && Number.isFinite(size.height) && size.width > 0 && size.height > 0) {
        state.referenceSize = { width: size.width, height: size.height, source: 'paste' };
      }
    } catch {
      /* storage unavailable: defaults are fine */
    }
  }

  function persist() {
    try {
      const saved = {
        box: state.box,
        color: state.color,
        opacity: state.opacity,
        showBox: state.showBox,
        pixelUnits: state.pixelUnits,
        pastedSize: state.referenceSize?.source === 'paste' ? state.referenceSize : null,
      };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(saved));
    } catch {
      /* ignore */
    }
  }

  // -------------------------------------------------------------------------------------------
  // Geometry — mirrors BasicImagePage / ISVImageScrollView / ZTronImagePage / ZTronSVGView

  function computeGeometry() {
    const viewportWidth = el.viewport.clientWidth;
    const viewportHeight = el.viewport.clientHeight;

    // The carousel page (and so the image scroll view) is always constrained to 16:9.
    const page = S.sizeThatFits(
      Math.max(1, viewportWidth - 2 * PAGE_PADDING),
      Math.max(1, viewportHeight - 2 * PAGE_PADDING),
      CAROUSEL_ASPECT_RATIO,
    );

    // ISVImageScrollView: the image view is aspect-fit in the scroll view and centered by the content offset.
    const imageAspectRatio = state.image ? state.image.width / state.image.height : CAROUSEL_ASPECT_RATIO;
    const fitted = S.sizeThatFits(page.width, page.height, imageAspectRatio);
    const imageRect = { x: (page.width - fitted.width) / 2, y: (page.height - fitted.height) / 2, ...fitted };

    // ZTronImagePage.makePlaceablesConstraintsIfNeeded: placeables are offset from the image view's
    // origin and normalized against a 16:9 fit of the scroll view's bounds.
    const container = { x: imageRect.x, y: imageRect.y, ...S.sizeThatFits(page.width, page.height, CAROUSEL_ASPECT_RATIO) };

    const { zoom, panX, panY } = state.view;
    const pageOrigin = { x: (viewportWidth - page.width) / 2, y: (viewportHeight - page.height) / 2 };
    const origin = { x: pageOrigin.x + panX, y: pageOrigin.y + panY };
    return { viewportWidth, viewportHeight, page, pageOrigin, origin, zoom, imageRect, container };
  }

  const toScreenRect = (g, r) => ({ x: g.origin.x + g.zoom * r.x, y: g.origin.y + g.zoom * r.y, width: g.zoom * r.width, height: g.zoom * r.height });

  /** ZTronSVGView.getOrigin/getSize + SVGLayer.resizeToFit, in page coordinates. */
  function placement(g) {
    const b = state.box;
    const rect = {
      x: g.container.x + b.x * g.container.width,
      y: g.container.y + b.y * g.container.height,
      width: b.width * g.container.width,
      height: b.height * g.container.height,
    };
    const boundingBox = state.outline?.model.boundingBox;
    const scale = boundingBox ? S.resizeToFitScale(boundingBox, rect.width, rect.height) : null;
    return { rect, scale };
  }

  // -------------------------------------------------------------------------------------------
  // Rendering

  function scheduleRender() {
    if (renderQueued) return;
    renderQueued = true;
    requestAnimationFrame(() => {
      renderQueued = false;
      render();
    });
  }

  function setRect(node, r) {
    node.setAttribute('x', r.x);
    node.setAttribute('y', r.y);
    node.setAttribute('width', Math.max(0, r.width));
    node.setAttribute('height', Math.max(0, r.height));
  }

  const matrixAttribute = (m) => `matrix(${m.a} ${m.b} ${m.c} ${m.d} ${m.tx} ${m.ty})`;

  function render() {
    const g = (geometry = computeGeometry());
    const { rect, scale } = placement(g);

    el.world.setAttribute('transform', `matrix(${g.zoom} 0 0 ${g.zoom} ${g.origin.x} ${g.origin.y})`);
    setRect(el.pageBackground, { x: 0, y: 0, ...g.page });
    if (state.image) {
      setRect(el.photo, g.imageRect);
      el.photo.style.display = '';
    } else {
      el.photo.style.display = 'none';
    }

    // Outline: shape → (its transforms) → SVGLayer scale → ZTronSVGView origin. Stroke width is
    // in shape-local units, exactly like CAShapeLayer.lineWidth under the layer transforms.
    const lineWidth = S.lineWidthForZoom(state.box, g.zoom);
    const drawable = state.outline && Number.isFinite(scale) && scale > 0;
    if (drawable) {
      const base = S.concat(S.scaling(scale, scale), S.translation(rect.x, rect.y));
      state.outline.model.shapes.forEach((shape, i) => {
        const path = state.outline.paths[i];
        path.setAttribute('transform', matrixAttribute(S.concat(shape.transform, base)));
        path.setAttribute('stroke-width', lineWidth);
      });
      el.outline.setAttribute('stroke', state.color);
      el.outline.setAttribute('stroke-opacity', state.opacity);
      el.outline.style.display = '';
    } else {
      el.outline.style.display = 'none';
    }

    // Screen-space chrome
    const pageScreen = toScreenRect(g, { x: 0, y: 0, ...g.page });
    el.outsideMask.setAttribute(
      'd',
      `M0 0H${g.viewportWidth}V${g.viewportHeight}H0Z M${pageScreen.x} ${pageScreen.y}h${pageScreen.width}v${pageScreen.height}h${-pageScreen.width}Z`,
    );
    setRect(el.pageFrame, pageScreen);

    const imageIsCarouselShaped =
      Math.abs(g.container.width - g.imageRect.width) < 0.5 && Math.abs(g.container.height - g.imageRect.height) < 0.5;
    el.containerFrame.style.display = state.image && !imageIsCarouselShaped ? '' : 'none';
    setRect(el.containerFrame, toScreenRect(g, g.container));

    const boxScreen = toScreenRect(g, rect);
    setRect(el.aabb, boxScreen);
    el.aabb.classList.toggle('hidden-box', !state.showBox);

    let drawnBounds = null;
    if (drawable && state.outline.paths.length > 0) {
      const b = el.outline.getBBox();
      drawnBounds = { x: b.x, y: b.y, width: b.width, height: b.height };
      setRect(el.outlineHit, toScreenRect(g, drawnBounds));
      el.outlineHit.style.display = '';
    } else {
      el.outlineHit.style.display = 'none';
    }

    const showEdgeThumbs = boxScreen.width > 34 && boxScreen.height > 34;
    for (const [handle, [fx, fy]] of Object.entries(HANDLES)) {
      const { group, hit, visible } = thumbs[handle];
      const cx = boxScreen.x + fx * boxScreen.width;
      const cy = boxScreen.y + fy * boxScreen.height;
      group.style.display = handle.length === 1 && !showEdgeThumbs ? 'none' : '';
      setRect(hit, { x: cx - THUMB_HIT_SIZE / 2, y: cy - THUMB_HIT_SIZE / 2, width: THUMB_HIT_SIZE, height: THUMB_HIT_SIZE });
      setRect(visible, { x: cx - THUMB_SIZE / 2, y: cy - THUMB_SIZE / 2, width: THUMB_SIZE, height: THUMB_SIZE });
    }

    el.emptyHint.style.display = state.image || state.outline ? 'none' : '';
    el.zoomLabel.textContent = `${Math.round(g.zoom * 100)}%`;

    renderInputs();
    renderInfo(g, scale, lineWidth, drawnBounds);
    renderNotes(g, imageIsCarouselShaped);
    el.readout.replaceChildren(...readoutNodes());
    el.undo.disabled = history.index <= 0;
    el.redo.disabled = history.index >= history.entries.length - 1;
    el.fitBox.disabled = !drawable;
  }

  function renderInputs() {
    const reference = pixelMode() ? pixelReference() : null;
    for (const [key, input] of Object.entries(el.inputs)) {
      if (document.activeElement === input) continue;
      input.value = reference ? fmtPixels(state.box[key] * dimensionFor(key, reference)) : fmt(state.box[key]);
    }
    el.pixelUnits.checked = state.pixelUnits;
    el.pixelUnits.disabled = !state.referenceSize;
    el.boxTitle.textContent = reference ? 'Bounding box (px)' : 'Normalized bounding box';
    el.unitsHint.hidden = !state.referenceSize && !state.pixelUnits;
    el.unitsHint.textContent = state.referenceSize ? sizeDescription(state.referenceSize) : 'Load an image or paste fractions to set a size.';
    el.color.value = state.color;
    el.opacity.value = state.opacity;
    el.showBox.checked = state.showBox;
  }

  function sizeDescription(size) {
    const dimensions = `${fmtPixels(size.width)} × ${fmtPixels(size.height)}`;
    if (size.source === 'paste') return `Size ${dimensions}, from the pasted fractions.`;
    const image = state.image;
    if (image && (image.width !== size.width || image.height !== size.height)) {
      return `Size ${dimensions}, the 16:9 frame of the ${image.width} × ${image.height} image.`;
    }
    return `Size ${dimensions}, the image resolution.`;
  }

  function readoutNodes() {
    const parts = ['boundingBox: .init('];
    BoxText.KEYS.forEach((key, i) => {
      parts.push(`${i === 0 ? '' : ', '}${key}: `, [BoxText.formatArgument(state.box, key, pixelReference())]);
    });
    parts.push(')   // image ', [imageResolution()]);
    return parts.map((part) => {
      if (typeof part === 'string') return document.createTextNode(part);
      const strong = document.createElement('b');
      strong.textContent = part[0];
      return strong;
    });
  }

  function renderInfo(g, scale, lineWidth, drawnBounds) {
    const rows = [];
    const model = state.outline?.model;
    const diagonal = Math.hypot(state.box.width, state.box.height);
    rows.push(['Line width', `${+lineWidth.toFixed(2)}`]);
    rows.push(['', `diag ${diagonal.toFixed(3)} ${diagonal >= 0.07 ? '≥' : '<'} 0.07`]);
    if (model?.boundingBox) {
      const bb = model.boundingBox;
      rows.push(['resizeToFit scale', Number.isFinite(scale) ? scale.toFixed(5) : '—']);
      rows.push(['SwiftSVG bbox', `${+bb.x.toFixed(2)}, ${+bb.y.toFixed(2)}, ${+bb.width.toFixed(2)} × ${+bb.height.toFixed(2)}`]);
    }
    if (model?.viewBox) {
      const vb = model.viewBox;
      rows.push(['viewBox', `${vb.x} ${vb.y} ${vb.width} ${vb.height}`]);
    }
    if (drawnBounds) {
      const n = {
        x: (drawnBounds.x - g.container.x) / g.container.width,
        y: (drawnBounds.y - g.container.y) / g.container.height,
        width: drawnBounds.width / g.container.width,
        height: drawnBounds.height / g.container.height,
      };
      rows.push(['Drawn outline', `${n.x.toFixed(4)}, ${n.y.toFixed(4)}`]);
      rows.push(['', `${n.width.toFixed(4)} × ${n.height.toFixed(4)}`]);
    }
    el.renderInfo.replaceChildren(
      ...rows.flatMap(([term, value]) => {
        const dt = document.createElement('dt');
        const dd = document.createElement('dd');
        dt.textContent = term;
        dd.textContent = value;
        return [dt, dd];
      }),
    );
  }

  function renderNotes(g, imageIsCarouselShaped) {
    const notes = [];
    if (state.error) notes.push(['fatal', state.error]);
    if (state.outline) {
      for (const message of state.outline.model.fatal) notes.push(['fatal', message]);
      for (const message of state.outline.model.warnings) notes.push(['warn', message]);
    }
    if (state.image && !imageIsCarouselShaped) {
      notes.push([
        'warn',
        `The image is not 16:9. The carousel normalizes against a 16:9 box anchored at the image's top-left corner (dashed), which this view reproduces.`,
      ]);
    }
    if (state.image && state.image.orientation !== 1) {
      notes.push(['warn', `The HEIC has EXIF orientation ${state.image.orientation}; UIImage displays it rotated while this view shows the raw pixels.`]);
    }
    el.notesSection.hidden = notes.length === 0;
    el.notes.replaceChildren(
      ...notes.map(([kind, message]) => {
        const li = document.createElement('li');
        li.className = kind;
        li.textContent = message;
        return li;
      }),
    );
  }

  // -------------------------------------------------------------------------------------------
  // History + log

  function commit(reason) {
    const snapshot = { ...state.box };
    const current = history.entries[history.index];
    if (current && sameBox(current, snapshot)) return;
    history.entries = history.entries.slice(0, history.index + 1);
    history.entries.push(snapshot);
    history.index = history.entries.length - 1;
    persist();
    logBox(reason);
    scheduleRender();
  }

  function stepHistory(delta) {
    const index = history.index + delta;
    if (index < 0 || index >= history.entries.length) return;
    history.index = index;
    state.box = { ...history.entries[index] };
    persist();
    logBox(delta < 0 ? 'undo' : 'redo');
    scheduleRender();
  }

  function appendLog(text, className) {
    const time = new Date().toLocaleTimeString([], { hour12: false });
    const li = document.createElement('li');
    if (className) li.className = className;
    const stamp = document.createElement('span');
    stamp.className = 'time';
    stamp.textContent = `${time}  `;
    li.append(stamp, text);
    el.log.append(li);
    while (el.log.children.length > 500) el.log.firstElementChild.remove();
    el.log.scrollTop = el.log.scrollHeight;
    bridge?.log(`[${time}] ${text}`);
  }

  const logBox = (reason) =>
    appendLog(`${BoxText.formatInit(state.box, pixelReference(), { multiline: false })}   // image ${imageResolution()} · ${reason}`);
  const logEvent = (text) => appendLog(text, 'event');

  async function copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const area = document.createElement('textarea');
      area.value = text;
      document.body.append(area);
      area.select();
      document.execCommand('copy');
      area.remove();
    }
    logEvent(`Copied ${text.replace(/\s*\n\s*/g, ' ')}`);
  }

  // -------------------------------------------------------------------------------------------
  // Box editing

  function clampBox(box, handle = '') {
    let { x, y, width, height } = box;
    if (x < 0) {
      if (handle.includes('w')) width += x;
      x = 0;
    }
    if (y < 0) {
      if (handle.includes('n')) height += y;
      y = 0;
    }
    if (width > 1) {
      if (handle.includes('w')) x += width - 1;
      width = 1;
    }
    if (height > 1) {
      if (handle.includes('n')) y += height - 1;
      height = 1;
    }
    return {
      x: Math.min(x, 1),
      y: Math.min(y, 1),
      width: Math.max(width, MIN_BOX_SIZE),
      height: Math.max(height, MIN_BOX_SIZE),
    };
  }

  /** Resizes a page-space rect from a thumb. `keepAspect` and `fromCenter` follow common editor conventions. */
  function resizeRect(start, handle, dx, dy, keepAspect, fromCenter) {
    const hasW = handle.includes('w');
    const hasE = handle.includes('e');
    const hasN = handle.includes('n');
    const hasS = handle.includes('s');
    const growX = (hasE ? dx : 0) - (hasW ? dx : 0);
    const growY = (hasS ? dy : 0) - (hasN ? dy : 0);
    const factor = fromCenter ? 2 : 1;
    const minimum = 1;

    let width = start.width + factor * growX;
    let height = start.height + factor * growY;

    if (keepAspect) {
      const horizontal = hasE || hasW;
      const vertical = hasN || hasS;
      let k;
      if (horizontal && vertical) k = Math.max(width / start.width, height / start.height);
      else if (horizontal) k = width / start.width;
      else k = height / start.height;
      k = Math.max(k, minimum / start.width, minimum / start.height);
      width = start.width * k;
      height = start.height * k;
    } else {
      width = Math.max(minimum, width);
      height = Math.max(minimum, height);
    }

    const centerX = start.x + start.width / 2;
    const centerY = start.y + start.height / 2;
    let x;
    let y;
    if (fromCenter || (!hasW && !hasE)) x = centerX - width / 2;
    else x = hasW ? start.x + start.width - width : start.x;
    if (fromCenter || (!hasN && !hasS)) y = centerY - height / 2;
    else y = hasN ? start.y + start.height - height : start.y;

    return { x, y, width, height };
  }

  function setBoxFromPageRect(r, container, handle) {
    state.box = clampBox(
      {
        x: (r.x - container.x) / container.width,
        y: (r.y - container.y) / container.height,
        width: r.width / container.width,
        height: r.height / container.height,
      },
      handle,
    );
  }

  function fitBoxToOutline() {
    const g = geometry || computeGeometry();
    const { scale } = placement(g);
    const bb = state.outline?.model.boundingBox;
    if (!bb || !Number.isFinite(scale)) return;
    // With the box at the bounding box's aspect ratio, resizeToFit keeps the exact same scale.
    state.box = clampBox({
      ...state.box,
      width: (scale * bb.width) / g.container.width,
      height: (scale * bb.height) / g.container.height,
    });
    commit('fit box to outline');
  }

  function nudge(dx, dy, resize) {
    const g = geometry || computeGeometry();
    const px = 1 / g.zoom; // one screen pixel, in page units
    const b = { ...state.box };
    if (resize) {
      b.width += (dx * px) / g.container.width;
      b.height += (dy * px) / g.container.height;
    } else {
      b.x += (dx * px) / g.container.width;
      b.y += (dy * px) / g.container.height;
    }
    state.box = clampBox(b);
    scheduleRender();
    clearTimeout(nudgeCommitTimer);
    nudgeCommitTimer = setTimeout(() => commit(resize ? 'keyboard resize' : 'keyboard nudge'), 350);
  }

  // -------------------------------------------------------------------------------------------
  // View (zoom / pan)

  function zoomAt(point, zoom) {
    const g = geometry || computeGeometry();
    const target = clamp(zoom, ZOOM_MIN, ZOOM_MAX);
    const world = { x: (point.x - g.origin.x) / g.zoom, y: (point.y - g.origin.y) / g.zoom };
    state.view.zoom = target;
    state.view.panX = point.x - target * world.x - g.pageOrigin.x;
    state.view.panY = point.y - target * world.y - g.pageOrigin.y;
    scheduleRender();
  }

  const viewportCenter = () => ({ x: el.viewport.clientWidth / 2, y: el.viewport.clientHeight / 2 });
  const zoomBy = (factor) => zoomAt(viewportCenter(), state.view.zoom * factor);

  function resetView() {
    state.view = { zoom: 1, panX: 0, panY: 0 };
    scheduleRender();
  }

  function viewportPoint(event) {
    const bounds = el.viewport.getBoundingClientRect();
    return { x: event.clientX - bounds.left, y: event.clientY - bounds.top };
  }

  // -------------------------------------------------------------------------------------------
  // Files

  function reportError(error) {
    const message = String(error?.message || error).replace(/^Error invoking remote method '[^']+': (Error: )?/, '');
    state.error = message;
    logEvent(`Error: ${message}`);
    scheduleRender();
  }

  /** Loads an image; with a known file path, also loads `<image name>.svg` from under its directory. */
  async function loadImage({ name, path, bytes, mime, orientation = 1 }, { autoOutline = true } = {}) {
    const blob = bytes instanceof Blob ? bytes : new Blob([bytes], { type: mime });
    const url = URL.createObjectURL(blob);
    const image = new Image();
    image.src = url;
    try {
      await image.decode();
    } catch {
      URL.revokeObjectURL(url);
      throw new Error(`Could not decode ${name}.`);
    }
    if (state.image) URL.revokeObjectURL(state.image.url);
    state.image = { name, url, width: image.naturalWidth, height: image.naturalHeight, orientation };
    state.referenceSize = { ...imageReferenceSize(state.image), source: 'image' };
    state.error = null;
    el.photo.setAttribute('href', url);
    el.imageName.textContent = name;
    el.imageName.classList.remove('muted');
    el.imageInfo.textContent = `${image.naturalWidth} × ${image.naturalHeight} px`;
    logEvent(`Loaded image ${name} (${image.naturalWidth} × ${image.naturalHeight} px)`);
    logBox('image loaded');
    scheduleRender();
    if (autoOutline && path && bridge) await loadCompanionOutline(path, name);
  }

  async function loadCompanionOutline(imagePath, imageName) {
    const outlineName = `${imageName.replace(/\.[^.]+$/, '')}.svg`;
    try {
      const found = await bridge.findOutline(imagePath);
      if (typeof found.text !== 'string') {
        logEvent(
          found.truncated
            ? `Stopped looking for ${outlineName}: too many files under ${found.root}`
            : `No ${outlineName} under ${found.root}`,
        );
        return;
      }
      const others = found.alternatives ? ` (${found.alternatives} more at the same depth ignored)` : '';
      logEvent(`Found ${found.relativePath} next to the image${others}`);
      loadOutline(found);
    } catch (error) {
      reportError(error);
    }
  }

  function loadOutline({ name, text }) {
    const model = S.parse(text);
    const paths = model.shapes.map((shape) => {
      const path = document.createElementNS(SVG_NS, 'path');
      path.setAttribute('d', shape.d);
      path.setAttribute('stroke-linecap', shape.lineCap);
      path.setAttribute('stroke-linejoin', shape.lineJoin);
      path.setAttribute('stroke-miterlimit', shape.miterLimit);
      if (shape.opacity < 1) path.setAttribute('opacity', shape.opacity);
      return path;
    });
    el.outline.replaceChildren(...paths);
    state.outline = { name, model, paths };
    state.error = null;

    el.outlineName.textContent = name;
    el.outlineName.classList.remove('muted');
    const bb = model.boundingBox;
    el.outlineInfo.textContent = `${model.shapes.length} shape${model.shapes.length === 1 ? '' : 's'}${
      bb ? ` · bbox ${+bb.width.toFixed(2)} × ${+bb.height.toFixed(2)}` : ''
    }`;
    logEvent(`Loaded outline ${name} (${model.shapes.length} shapes${model.ok ? '' : ', SwiftSVG would fail on it'})`);
    scheduleRender();
  }

  async function openImage() {
    if (!bridge) return el.fileImage.click();
    try {
      const result = await bridge.openImage();
      if (result) await loadImage(result);
    } catch (error) {
      reportError(error);
    }
  }

  async function openOutline() {
    if (!bridge) return el.fileOutline.click();
    try {
      const result = await bridge.openOutline();
      if (result) loadOutline(result);
    } catch (error) {
      reportError(error);
    }
  }

  async function loadFile(file, options) {
    const extension = file.name.split('.').pop().toLowerCase();
    if (extension === 'svg') return loadOutline({ name: file.name, text: await file.text() });
    if (['png', 'jpg', 'jpeg'].includes(extension)) {
      return loadImage({ name: file.name, path: bridge?.pathForFile(file) || null, bytes: file }, options);
    }
    if (['heic', 'heif'].includes(extension)) {
      if (!bridge) throw new Error('HEIC images can only be opened in the Electron app (they are decoded with macOS sips).');
      return loadImage(await bridge.readImage(bridge.pathForFile(file)), options);
    }
    throw new Error(`Unsupported file "${file.name}". Use .svg, .heic, .png, .jpg or .jpeg.`);
  }

  // -------------------------------------------------------------------------------------------
  // Events

  function buildThumbs() {
    for (const handle of Object.keys(HANDLES)) {
      const group = document.createElementNS(SVG_NS, 'g');
      group.dataset.handle = handle;
      group.style.cursor = CURSORS[handle];
      const hit = document.createElementNS(SVG_NS, 'rect');
      hit.setAttribute('class', 'thumb-hit');
      const visible = document.createElementNS(SVG_NS, 'rect');
      visible.setAttribute('class', 'thumb');
      group.append(hit, visible);
      el.thumbs.append(group);
      thumbs[handle] = { group, hit, visible };
    }
  }

  function onPointerDown(event) {
    if (event.button !== 0 && event.button !== 1) return;
    if (document.activeElement && document.activeElement !== document.body) document.activeElement.blur();

    const handle = event.target.closest('[data-handle]')?.dataset.handle;
    const onBox = event.target.classList?.contains('move-target');
    const g = geometry || computeGeometry();

    if (event.button === 1 || spaceHeld || (!handle && !onBox)) {
      drag = { kind: 'pan', startX: event.clientX, startY: event.clientY, panX: state.view.panX, panY: state.view.panY };
      el.viewport.classList.add('panning');
    } else {
      drag = {
        kind: handle ? 'resize' : 'move',
        handle: handle || '',
        startX: event.clientX,
        startY: event.clientY,
        box: { ...state.box },
        rect: placement(g).rect,
        container: { ...g.container },
        zoom: g.zoom,
      };
      el.overlay.classList.add('dragging');
    }
    el.overlay.setPointerCapture(event.pointerId);
    event.preventDefault();
  }

  function onPointerMove(event) {
    if (!drag) return;
    const dx = event.clientX - drag.startX;
    const dy = event.clientY - drag.startY;

    if (drag.kind === 'pan') {
      state.view.panX = drag.panX + dx;
      state.view.panY = drag.panY + dy;
    } else if (drag.kind === 'move') {
      let mx = dx / drag.zoom;
      let my = dy / drag.zoom;
      if (event.shiftKey) {
        if (Math.abs(mx) > Math.abs(my)) my = 0;
        else mx = 0;
      }
      state.box = clampBox({
        ...drag.box,
        x: drag.box.x + mx / drag.container.width,
        y: drag.box.y + my / drag.container.height,
      });
    } else {
      const r = resizeRect(drag.rect, drag.handle, dx / drag.zoom, dy / drag.zoom, event.shiftKey, event.altKey);
      setBoxFromPageRect(r, drag.container, drag.handle);
    }
    scheduleRender();
  }

  function onPointerUp() {
    if (!drag) return;
    const kind = drag.kind;
    drag = null;
    el.viewport.classList.remove('panning');
    el.overlay.classList.remove('dragging');
    if (kind !== 'pan') commit(kind);
  }

  function onWheel(event) {
    event.preventDefault();
    const unit = event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? el.viewport.clientHeight : 1;
    if (event.ctrlKey || event.metaKey) {
      zoomAt(viewportPoint(event), state.view.zoom * Math.exp(-event.deltaY * unit * 0.01));
    } else {
      state.view.panX -= event.deltaX * unit;
      state.view.panY -= event.deltaY * unit;
      scheduleRender();
    }
  }

  const isEditing = () => document.activeElement?.tagName === 'INPUT';

  function onKeyDown(event) {
    const command = event.metaKey || event.ctrlKey;
    const key = event.key;

    // In Electron these shortcuts belong to the application menu.
    if (!bridge && command) {
      if (key.toLowerCase() === 'o') {
        event.preventDefault();
        return event.shiftKey ? openOutline() : openImage();
      }
      if (key === '=' || key === '+') return event.preventDefault(), zoomBy(1.25);
      if (key === '-') return event.preventDefault(), zoomBy(0.8);
      if (key === '0') return event.preventDefault(), resetView();
    }

    if (isEditing()) return;

    if (command && key.toLowerCase() === 'z') {
      event.preventDefault();
      return stepHistory(event.shiftKey ? 1 : -1);
    }
    if (key === ' ') {
      spaceHeld = true;
      el.viewport.classList.add('space-held');
      return event.preventDefault();
    }
    const arrows = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
    if (arrows[key] && !command) {
      event.preventDefault();
      const step = event.shiftKey ? 10 : 1;
      nudge(arrows[key][0] * step, arrows[key][1] * step, event.altKey);
    }
  }

  function onKeyUp(event) {
    if (event.key === ' ') {
      spaceHeld = false;
      el.viewport.classList.remove('space-held');
    }
  }

  function wire() {
    el.overlay.addEventListener('pointerdown', onPointerDown);
    el.overlay.addEventListener('pointermove', onPointerMove);
    el.overlay.addEventListener('pointerup', onPointerUp);
    el.overlay.addEventListener('pointercancel', onPointerUp);
    el.overlay.addEventListener('dblclick', (event) => {
      if (!event.target.closest('[data-handle]') && !event.target.classList?.contains('move-target')) resetView();
    });
    el.viewport.addEventListener('wheel', onWheel, { passive: false });
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', () => {
      spaceHeld = false;
      el.viewport.classList.remove('space-held');
    });
    new ResizeObserver(scheduleRender).observe(el.viewport);

    window.addEventListener('dragover', (event) => event.preventDefault());
    window.addEventListener('drop', async (event) => {
      event.preventDefault();
      // An outline dropped together with the image wins over the one found next to it.
      const isOutline = (file) => /\.svg$/i.test(file.name);
      const files = Array.from(event.dataTransfer.files).sort((a, b) => isOutline(a) - isOutline(b));
      const autoOutline = !files.some(isOutline);
      for (const file of files) {
        try {
          await loadFile(file, { autoOutline });
        } catch (error) {
          reportError(error);
        }
      }
    });

    $('open-image').addEventListener('click', openImage);
    $('open-outline').addEventListener('click', openOutline);
    for (const input of [el.fileImage, el.fileOutline]) {
      input.addEventListener('change', async () => {
        const file = input.files[0];
        input.value = '';
        if (!file) return;
        try {
          await loadFile(file);
        } catch (error) {
          reportError(error);
        }
      });
    }

    for (const [key, input] of Object.entries(el.inputs)) {
      input.addEventListener('input', () => {
        const text = input.value.trim().replace(',', '.');
        const value = Number(text);
        if (text === '' || !Number.isFinite(value)) return;
        const normalized = pixelMode() ? value / dimensionFor(key, pixelReference()) : value;
        state.box = clampBox({ ...state.box, [key]: normalized });
        scheduleRender();
      });
      input.addEventListener('change', () => commit(`edited ${key}`));
      input.addEventListener('blur', scheduleRender);
      input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') input.blur();
        if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
          event.preventDefault();
          const direction = event.key === 'ArrowUp' ? 1 : -1;
          const reference = pixelMode() ? pixelReference() : null;
          const step = reference
            ? ((event.shiftKey ? 10 : 1) * direction) / dimensionFor(key, reference)
            : (event.shiftKey ? 0.01 : 0.0001) * direction;
          state.box = clampBox({ ...state.box, [key]: state.box[key] + step });
          input.value = reference ? fmtPixels(state.box[key] * dimensionFor(key, reference)) : fmt(state.box[key]);
          scheduleRender();
          clearTimeout(nudgeCommitTimer);
          nudgeCommitTimer = setTimeout(() => commit(`edited ${key}`), 350);
        }
      });
    }

    const showPasteStatus = (message, isError = false) => {
      el.pasteStatus.hidden = false;
      el.pasteStatus.textContent = message;
      el.pasteStatus.classList.toggle('error', isError);
    };
    const applyPaste = () => {
      if (!el.pasteBox.value.trim()) return;
      let result;
      try {
        result = BoxText.parse(el.pasteBox.value, pixelReference());
      } catch (error) {
        showPasteStatus(error.message, true);
        return;
      }
      if (result.detectedSize) {
        state.referenceSize = { ...result.detectedSize, source: 'paste' };
        logEvent(`Detected size ${fmtPixels(result.detectedSize.width)} × ${fmtPixels(result.detectedSize.height)} from the pasted fractions`);
      }
      state.box = clampBox(result.box);

      const reference = pixelReference();
      let message = {
        fractions: result.detectedSize
          ? `Read as fractions of ${fmtPixels(result.detectedSize.width)} × ${fmtPixels(result.detectedSize.height)}.`
          : `Read as fractions. ${result.note}`,
        normalized: 'Read as normalized values.',
        pixels: reference && `Read as pixels of ${fmtPixels(reference.width)} × ${fmtPixels(reference.height)}.`,
      }[result.kind];
      if (!sameBox(state.box, result.box)) message += ' Some values were clamped to 0…1.';
      showPasteStatus(message);
      commit(`pasted ${result.kind}`);
      el.pasteBox.select();
    };
    el.pasteBox.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        applyPaste();
      }
    });
    // A paste replaces the whole field (so an earlier box can't linger in front of the new one),
    // with every line's indentation stripped.
    el.pasteBox.addEventListener('paste', (event) => {
      const text = event.clipboardData?.getData('text/plain');
      if (text === undefined) return;
      event.preventDefault();
      el.pasteBox.value = text
        .split(/\r?\n/)
        .map((line) => line.replace(/^\s+/, '').trimEnd())
        .join('\n')
        .trim();
      applyPaste();
    });

    el.fitBox.addEventListener('click', fitBoxToOutline);
    el.undo.addEventListener('click', () => stepHistory(-1));
    el.redo.addEventListener('click', () => stepHistory(1));

    el.color.addEventListener('input', () => {
      state.color = el.color.value;
      persist();
      scheduleRender();
    });
    el.opacity.addEventListener('input', () => {
      state.opacity = Number(el.opacity.value);
      persist();
      scheduleRender();
    });
    el.pixelUnits.addEventListener('change', () => {
      state.pixelUnits = el.pixelUnits.checked;
      persist();
      scheduleRender();
    });
    el.showBox.addEventListener('change', () => {
      state.showBox = el.showBox.checked;
      persist();
      scheduleRender();
    });

    $('zoom-in').addEventListener('click', () => zoomBy(1.25));
    $('zoom-out').addEventListener('click', () => zoomBy(0.8));
    el.zoomLabel.addEventListener('click', resetView);

    $('copy-init').addEventListener('click', () => copyText(BoxText.formatInit(state.box, pixelReference())));
    $('clear-log').addEventListener('click', () => el.log.replaceChildren());

    bridge?.onMenuCommand((command) => {
      if (command === 'open-image') openImage();
      else if (command === 'open-outline') openOutline();
      else if (command === 'zoom-in') zoomBy(1.25);
      else if (command === 'zoom-out') zoomBy(0.8);
      else if (command === 'zoom-reset') resetView();
    });
  }

  restore();
  buildThumbs();
  wire();
  history.entries.push({ ...state.box });
  history.index = 0;
  render();
  logBox('start');
})();
