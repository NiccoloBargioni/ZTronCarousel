/*
 * Emulation of how ZTronSVGView renders an outline through SwiftSVG (mchoe/SwiftSVG@master).
 *
 * This deliberately reproduces SwiftSVG's behavior, quirks included, rather than standard SVG
 * semantics, so what you see here is what the carousel draws:
 *   - Only svg, g, path, rect, circle, ellipse, line, polygon, polyline are parsed. Unsupported
 *     elements are skipped but their children are still parsed (so shapes inside <defs> render).
 *   - The `d` attribute goes through a port of SwiftSVG's PathDLexer (no arc support, its own
 *     number splitting rules, consecutive `M`s turn into lines).
 *   - `viewBox` never scales anything: it only offsets the root layer by (+minX, +minY).
 *   - `transform` lists are composed first-to-last (the reverse of the SVG spec), and SwiftSVG's
 *     own definitions of rotate(a, x, y), skewX and skewY are kept.
 *   - The bounding box used by `resizeToFit` is the union of every shape's CGPath.boundingBox,
 *     which includes Bezier control points and ignores every transform and the viewBox offset.
 *   - `resizeToFit` only scales (aspect fit); it never translates, so the bounding box origin is
 *     not compensated for.
 *   - ZTronSVGView then overrides fill (none), stroke color and line width on every shape layer,
 *     so the only per-shape styling that survives is line cap, line join, miter limit and the
 *     layer opacity a <g> pushes onto its direct children.
 */
(function (global) {
  'use strict';

  const SUPPORTED_TAGS = new Set(['svg', 'g', 'path', 'rect', 'circle', 'ellipse', 'line', 'polygon', 'polyline']);
  const SHAPE_TAGS = new Set(['path', 'rect', 'circle', 'ellipse', 'line', 'polygon', 'polyline']);
  const SILENTLY_IGNORED_TAGS = new Set(['title', 'desc', 'metadata', 'defs', 'style', 'sodipodi:namedview']);
  const SHAPES_RENDERED_INSIDE = new Set(['defs', 'clipPath', 'mask', 'symbol', 'marker', 'pattern']);

  const LINE_CAPS = new Set(['butt', 'round', 'square']);
  const LINE_JOINS = new Set(['miter', 'round', 'bevel']);

  // Bezier circle constant used by CoreGraphics for quarter arcs.
  const KAPPA = 0.5522847498307936;

  // ---------------------------------------------------------------------------------------------
  // DOM access (kept to the subset any XML DOM implementation offers)

  const attribute = (element, name) => (element.hasAttribute(name) ? element.getAttribute(name) : null);
  const elementChildren = (element) => Array.from(element.childNodes).filter((node) => node.nodeType === 1);
  const hasShapeDescendant = (element) =>
    elementChildren(element).some((child) => SHAPE_TAGS.has(child.tagName) || hasShapeDescendant(child));

  // ---------------------------------------------------------------------------------------------
  // Number parsing

  /** Swift's `Double(String)`: the whole string must be a number, no surrounding whitespace. */
  function swiftDouble(string) {
    return /^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/.test(string) ? Number(string) : null;
  }

  /** SwiftSVG's `Double(byteArray:)`: strtod on a NUL-terminated copy, accepted only if strtod consumed it all. */
  function strtodBytes(chars) {
    if (chars.length === 0) return null;
    let string = chars.join('');
    const nul = string.indexOf('\0');
    if (nul >= 0) string = string.slice(0, nul);
    const match = /^[ \t\n\v\f\r]*[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/.exec(string);
    if (!match) {
      // No conversion: strtod's end pointer is the start of the string, which is only NUL for "".
      return string.length === 0 ? 0 : null;
    }
    return match[0].length === string.length ? Number(match[0].trim()) : null;
  }

  /** SwiftSVG's `init?(lengthString:)`: a plain number, or one suffixed with px or mm (taken as-is). */
  function lengthDouble(string) {
    const plain = swiftDouble(string);
    if (plain !== null) return plain;
    for (const suffix of ['px', 'mm']) {
      if (string.endsWith(suffix)) {
        const value = swiftDouble(string.slice(0, -suffix.length));
        if (value !== null) return value;
      }
    }
    return null;
  }

  /** `String.trimWhitespace()`, i.e. trimming `CharacterSet.whitespaces` (spaces and tabs, not newlines). */
  function trimWhitespace(string) {
    return string.replace(/^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu, '');
  }

  // ---------------------------------------------------------------------------------------------
  // CGAffineTransform, with CoreGraphics' row-vector conventions.

  const IDENTITY = Object.freeze({ a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0 });

  /** `t1.concatenating(t2)`: apply t1, then t2. */
  function concat(t1, t2) {
    return {
      a: t1.a * t2.a + t1.b * t2.c,
      b: t1.a * t2.b + t1.b * t2.d,
      c: t1.c * t2.a + t1.d * t2.c,
      d: t1.c * t2.b + t1.d * t2.d,
      tx: t1.tx * t2.a + t1.ty * t2.c + t2.tx,
      ty: t1.tx * t2.b + t1.ty * t2.d + t2.ty,
    };
  }

  const translation = (x, y) => ({ a: 1, b: 0, c: 0, d: 1, tx: x, ty: y });
  const scaling = (x, y) => ({ a: x, b: 0, c: 0, d: y, tx: 0, ty: 0 });
  const rotation = (radians) => ({ a: Math.cos(radians), b: Math.sin(radians), c: -Math.sin(radians), d: Math.cos(radians), tx: 0, ty: 0 });

  function applyTransform(t, p) {
    return { x: t.a * p.x + t.c * p.y + t.tx, y: t.b * p.x + t.d * p.y + t.ty };
  }

  /** Port of `Transform(rawValue:coordinatesString:)`. */
  function singleTransform(name, coordinatesString) {
    const coordinates = coordinatesString
      .split(/[, ]/)
      .map((component) => swiftDouble(trimWhitespace(component)))
      .filter((value) => value !== null);
    if (coordinates.length === 0) return null;
    const [c0, c1] = coordinates;

    switch (name) {
      case 'matrix':
        if (coordinates.length < 6) return null;
        return { a: coordinates[0], b: coordinates[1], c: coordinates[2], d: coordinates[3], tx: coordinates[4], ty: coordinates[5] };
      case 'rotate':
        if (coordinates.length === 1) return rotation((c0 * Math.PI) / 180);
        if (coordinates.length === 3) {
          // SwiftSVG translates by (angle, cx) here, not (cx, cy). Kept as-is.
          return concat(concat(translation(c0, c1), rotation((c0 * Math.PI) / 180)), translation(-c0, -c1));
        }
        return null;
      case 'scale':
        return coordinates.length === 1 ? scaling(c0, c0) : scaling(c0, c1);
      case 'skewX':
        return { a: 1, b: Math.tan(c0), c: 0, d: 1, tx: 0, ty: 0 };
      case 'skewY':
        return { a: 1, b: 0, c: Math.tan(c0), d: 1, tx: 0, ty: 0 };
      case 'translate':
        return coordinates.length === 1 ? translation(c0, 0) : translation(c0, c1);
      default:
        return null;
    }
  }

  /** Port of `Transformable.transform(_:)`: matches combined first-to-last with `concatenating`. */
  function parseTransform(string) {
    const regex = /(\w+)\(((\-?\d+\.?\d*e?\-?\d*\s*,?\s*)+)\)/gi;
    let combined = IDENTITY;
    for (const match of string.matchAll(regex)) {
      const transform = singleTransform(match[1], match[2]);
      if (transform) combined = concat(combined, transform);
    }
    return combined;
  }

  // ---------------------------------------------------------------------------------------------
  // CGMutablePath, as far as SwiftSVG uses it through UIBezierPath.

  class CGPath {
    constructor() {
      this.elements = [];
      this.currentPoint = { x: 0, y: 0 };
      this.subpathStart = { x: 0, y: 0 };
    }

    moveTo(p) {
      // CoreGraphics replaces a moveTo that directly follows another moveTo.
      const last = this.elements[this.elements.length - 1];
      if (last && last.type === 'M') {
        last.points = [p];
      } else {
        this.elements.push({ type: 'M', points: [p] });
      }
      this.currentPoint = p;
      this.subpathStart = p;
    }

    lineTo(p) {
      this.elements.push({ type: 'L', points: [p] });
      this.currentPoint = p;
    }

    quadTo(control, p) {
      this.elements.push({ type: 'Q', points: [control, p] });
      this.currentPoint = p;
    }

    curveTo(control1, control2, p) {
      this.elements.push({ type: 'C', points: [control1, control2, p] });
      this.currentPoint = p;
    }

    close() {
      // CoreGraphics drops a closeSubpath that directly follows another one.
      const last = this.elements[this.elements.length - 1];
      if (!last || last.type !== 'Z') this.elements.push({ type: 'Z', points: [] });
      this.currentPoint = this.subpathStart;
    }

    /** CGPath.boundingBox: every point of every element, control points included. */
    boundingBox() {
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      for (const element of this.elements) {
        for (const p of element.points) {
          minX = Math.min(minX, p.x);
          minY = Math.min(minY, p.y);
          maxX = Math.max(maxX, p.x);
          maxY = Math.max(maxY, p.y);
        }
      }
      return minX === Infinity ? null : { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
    }

    toSVGPathData() {
      const n = (value) => +value.toFixed(6);
      return this.elements
        .map(({ type, points }) => type + points.map((p) => `${n(p.x)} ${n(p.y)}`).join(' '))
        .join(' ');
    }
  }

  function unionRect(r1, r2) {
    if (!r1) return r2;
    if (!r2) return r1;
    const x = Math.min(r1.x, r2.x);
    const y = Math.min(r1.y, r2.y);
    return {
      x,
      y,
      width: Math.max(r1.x + r1.width, r2.x + r2.width) - x,
      height: Math.max(r1.y + r1.height, r2.y + r2.height) - y,
    };
  }

  // ---------------------------------------------------------------------------------------------
  // <path d="..."> — port of PathDLexer + PathCommand.

  const PATH_COMMANDS = {
    M: ['moveTo', 2, false], m: ['moveTo', 2, true],
    C: ['curveTo', 6, false], c: ['curveTo', 6, true],
    Z: ['closePath', 0, false], z: ['closePath', 0, false],
    S: ['smoothCurveTo', 4, false], s: ['smoothCurveTo', 4, true],
    L: ['lineTo', 2, false], l: ['lineTo', 2, true],
    H: ['horizontalLineTo', 1, false], h: ['horizontalLineTo', 1, true],
    V: ['verticalLineTo', 1, false], v: ['verticalLineTo', 1, true],
    Q: ['quadCurveTo', 4, false], q: ['quadCurveTo', 4, true],
    T: ['smoothQuadCurveTo', 2, false], t: ['smoothQuadCurveTo', 2, true],
  };

  function makeCommand(letter) {
    const [type, required, relative] = PATH_COMMANDS[letter];
    return { type, required, relative, buffer: [] };
  }

  function canPushCommand(command) {
    if (command.required === 0) return true;
    if (command.buffer.length === 0) return false;
    return command.buffer.length % command.required === 0;
  }

  /** Port of `PathDLexer.next()`, collected into an array. Returned commands are value copies. */
  function lexPathData(pathString) {
    const chars = Array.from(pathString);
    chars.push('\0'); // utf8CString is NUL-terminated and its count includes the terminator.
    const count = chars.length;
    const commands = [];

    let index = 0;
    let current = null;
    let numbers = [];

    const pushCoordinateIfPossible = () => {
      if (numbers.length === 0) return;
      const value = strtodBytes(numbers);
      if (value !== null) {
        if (current) current.buffer.push(value);
        numbers = [];
      }
    };
    const copy = (command) => ({ ...command, buffer: command.buffer.slice() });

    const next = () => {
      if (current) current.buffer = [];

      while (index < count - 1) {
        const letter = chars[index];
        if (Object.prototype.hasOwnProperty.call(PATH_COMMANDS, letter)) {
          pushCoordinateIfPossible();
          index += 1;
          if (current && canPushCommand(current)) {
            const result = copy(current);
            current = makeCommand(letter);
            return result;
          }
          current = makeCommand(letter);
          numbers = [];
        }

        const character = chars[index];
        if (character === ',' || character === ' ') {
          pushCoordinateIfPossible();
          while ((chars[index] === ' ' || chars[index] === ',') && index < count) index += 1;
          if (current && canPushCommand(current)) {
            numbers = [];
            return copy(current);
          }
        } else if (character === '-' || (character === '.' && numbers.includes('.'))) {
          // Swift's `case sign, point where …` only guards `point`.
          pushCoordinateIfPossible();
          if (current && canPushCommand(current)) {
            numbers = [character];
            index += 1;
            return copy(current);
          }
        }

        numbers.push(chars[index]);
        index += 1;
      }

      if (current) {
        pushCoordinateIfPossible();
        const result = copy(current);
        current = null;
        return result;
      }
      return null;
    };

    for (let command = next(); command; command = next()) commands.push(command);
    return commands;
  }

  class SwiftCrash extends Error {}

  function executePathCommand(command, path, previous) {
    const buffer = command.buffer;
    const need = (n) => {
      if (buffer.length < n) {
        throw new SwiftCrash(`'${command.type}' was executed with ${buffer.length} of ${n} coordinates (index out of range)`);
      }
    };
    const cp = path.currentPoint;
    const point = (x, y) => (command.relative ? { x: x + cp.x, y: y + cp.y } : { x, y });

    switch (command.type) {
      case 'moveTo':
        need(2);
        if (previous && previous.type === 'moveTo') {
          path.lineTo(point(buffer[0], buffer[1])); // implicit lineTo, also after an explicit M
        } else {
          path.moveTo(point(buffer[0], buffer[1]));
        }
        break;
      case 'closePath':
        path.close();
        break;
      case 'lineTo':
        need(2);
        path.lineTo(point(buffer[0], buffer[1]));
        break;
      case 'horizontalLineTo':
        need(1);
        path.lineTo(command.relative ? { x: cp.x + buffer[0], y: cp.y } : { x: buffer[0], y: cp.y });
        break;
      case 'verticalLineTo':
        need(1);
        path.lineTo(command.relative ? { x: cp.x, y: cp.y + buffer[0] } : { x: cp.x, y: buffer[0] });
        break;
      case 'curveTo':
        need(6);
        path.curveTo(point(buffer[0], buffer[1]), point(buffer[2], buffer[3]), point(buffer[4], buffer[5]));
        break;
      case 'smoothCurveTo': {
        need(4);
        const end = point(buffer[2], buffer[3]);
        const controlEnd = point(buffer[0], buffer[1]);
        let controlStart = cp;
        if (previous && previous.type === 'curveTo') {
          const p = previous.buffer;
          if (!previous.relative) {
            controlStart = { x: 2 * cp.x - p[2], y: 2 * cp.y - p[3] };
          } else {
            const old = { x: cp.x - p[4], y: cp.y - p[5] };
            controlStart = { x: 2 * cp.x - (p[2] + old.x), y: 2 * cp.y - (p[3] + old.y) };
          }
        } else if (previous && previous.type === 'smoothCurveTo') {
          const p = previous.buffer;
          if (!previous.relative) {
            controlStart = { x: 2 * cp.x - p[0], y: 2 * cp.y - p[1] };
          } else {
            const old = { x: cp.x - p[2], y: cp.y - p[3] };
            controlStart = { x: 2 * cp.x - (p[0] + old.x), y: 2 * cp.y - (p[1] + old.y) };
          }
        }
        path.curveTo(controlStart, controlEnd, end);
        break;
      }
      case 'quadCurveTo':
        need(4);
        path.quadTo(point(buffer[0], buffer[1]), point(buffer[2], buffer[3]));
        break;
      case 'smoothQuadCurveTo': {
        need(2);
        const end = point(buffer[0], buffer[1]);
        let control = cp;
        if (previous && previous.type === 'quadCurveTo') {
          const p = previous.buffer;
          if (!previous.relative) {
            control = { x: 2 * cp.x - p[0], y: 2 * cp.y - p[1] };
          } else {
            // SwiftSVG adds the old current point back instead of subtracting it. Kept as-is.
            const old = { x: cp.x - p[2], y: cp.y - p[3] };
            control = { x: 2 * cp.x - p[0] + old.x, y: 2 * cp.y - p[1] + old.y };
          }
        }
        path.quadTo(control, end);
        break;
      }
    }
  }

  /** Port of `SVGPath.parseD(_:)`. */
  function pathFromD(d, issues) {
    const working = trimWhitespace(d);
    if (!(working.startsWith('M') || working.startsWith('m'))) {
      issues.warn(`A path's d does not start with M ("${working.slice(0, 24)}…"): SwiftSVG asserts on this in Debug builds.`);
    }
    if (/[Aa]/.test(working)) {
      issues.warn('A path uses arc commands (A/a). SwiftSVG has no arc support: those letters are read as garbage digits and the arc is dropped.');
    }

    const path = new CGPath();
    path.moveTo({ x: 0, y: 0 });
    let previous = null;
    try {
      for (const command of lexPathData(working)) {
        executePathCommand(command, path, previous);
        previous = command;
      }
    } catch (error) {
      if (!(error instanceof SwiftCrash)) throw error;
      issues.fatal(`SwiftSVG crashes on a path: ${error.message}. The app would terminate when this outline loads.`);
    }
    return path;
  }

  // ---------------------------------------------------------------------------------------------
  // Other shapes

  /** Port of CoordinateLexer (polygon/polyline points). */
  function lexPoints(string) {
    const chars = Array.from(trimWhitespace(string));
    chars.push('\0');
    const count = chars.length;
    const points = [];
    let index = 0;
    let numbers = [];

    for (;;) {
      let didParseX = false;
      const p = { x: 0, y: 0 };
      let produced = false;

      while (index < count - 1) {
        const character = chars[index];
        if (character === ',' || character === ' ') {
          index += 1;
          const value = strtodBytes(numbers);
          if (!didParseX) {
            if (value !== null) {
              p.x = value;
              numbers = [];
              didParseX = true;
            }
          } else if (value !== null) {
            p.y = value;
            numbers = [];
            produced = true;
            break;
          }
        } else {
          numbers.push(character);
          index += 1;
        }
      }

      if (!produced && didParseX) {
        const value = strtodBytes(numbers);
        if (value !== null) {
          p.y = value;
          numbers = [];
          produced = true;
        }
      }
      if (!produced) return points;
      points.push(p);
    }
  }

  function appendEllipse(path, cx, cy, rx, ry, closed) {
    // Four quarter Beziers starting at angle 0, like CoreGraphics' arc/oval construction.
    const kx = rx * KAPPA;
    const ky = ry * KAPPA;
    path.moveTo({ x: cx + rx, y: cy });
    path.curveTo({ x: cx + rx, y: cy + ky }, { x: cx + kx, y: cy + ry }, { x: cx, y: cy + ry });
    path.curveTo({ x: cx - kx, y: cy + ry }, { x: cx - rx, y: cy + ky }, { x: cx - rx, y: cy });
    path.curveTo({ x: cx - rx, y: cy - ky }, { x: cx - kx, y: cy - ry }, { x: cx, y: cy - ry });
    path.curveTo({ x: cx + kx, y: cy - ry }, { x: cx + rx, y: cy - ky }, { x: cx + rx, y: cy });
    if (closed) path.close();
  }

  function appendRect(path, x, y, width, height, cornerRadius) {
    if (cornerRadius <= 0) {
      path.moveTo({ x, y });
      path.lineTo({ x: x + width, y });
      path.lineTo({ x: x + width, y: y + height });
      path.lineTo({ x, y: y + height });
      path.close();
      return;
    }
    const r = Math.min(cornerRadius, Math.abs(width) / 2, Math.abs(height) / 2);
    const k = r * (1 - KAPPA);
    const right = x + width;
    const bottom = y + height;
    path.moveTo({ x: x + r, y });
    path.lineTo({ x: right - r, y });
    path.curveTo({ x: right - k, y }, { x: right, y: y + k }, { x: right, y: y + r });
    path.lineTo({ x: right, y: bottom - r });
    path.curveTo({ x: right, y: bottom - k }, { x: right - k, y: bottom }, { x: right - r, y: bottom });
    path.lineTo({ x: x + r, y: bottom });
    path.curveTo({ x: x + k, y: bottom }, { x, y: bottom - k }, { x, y: bottom - r });
    path.lineTo({ x, y: y + r });
    path.curveTo({ x, y: y + k }, { x: x + k, y }, { x: x + r, y });
    path.close();
  }

  function shapePath(element, tag, issues) {
    const number = (name, parse) => {
      const raw = attribute(element, name);
      if (raw === null) return 0;
      const value = parse(raw);
      return value === null ? 0 : value;
    };
    const path = new CGPath();

    switch (tag) {
      case 'path': {
        const d = attribute(element, 'd');
        return d === null ? null : pathFromD(d, issues);
      }
      case 'rect': {
        const rx = number('rx', swiftDouble);
        const ry = number('ry', swiftDouble);
        // UIBezierPath(roundedRect:byRoundingCorners:cornerRadii:) only honours cornerRadii.width.
        appendRect(path, number('x', swiftDouble), number('y', swiftDouble), number('width', swiftDouble), number('height', swiftDouble), rx > 0 || ry > 0 ? rx : 0);
        return path;
      }
      case 'circle': {
        // UIBezierPath(arcCenter:radius:startAngle:endAngle:clockwise:) leaves the arc open.
        const r = number('r', lengthDouble);
        appendEllipse(path, number('cx', lengthDouble), number('cy', lengthDouble), r, r, false);
        return path;
      }
      case 'ellipse':
        appendEllipse(path, number('cx', lengthDouble), number('cy', lengthDouble), number('rx', lengthDouble), number('ry', lengthDouble), true);
        return path;
      case 'line':
        path.moveTo({ x: number('x1', swiftDouble), y: number('y1', swiftDouble) });
        path.lineTo({ x: number('x2', swiftDouble), y: number('y2', swiftDouble) });
        return path;
      case 'polygon':
      case 'polyline': {
        const raw = attribute(element, 'points');
        if (raw === null) return null;
        lexPoints(raw).forEach((p, i) => (i === 0 ? path.moveTo(p) : path.lineTo(p)));
        if (tag === 'polygon') path.close();
        return path;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------------------------
  // Styling that survives ZTronSVGView's overrides

  /** Port of Stylable's regex; yields [name, value] pairs. */
  function styleDeclarations(style) {
    const regex = /(((\w+)-?(\w*)?):?([ #\w]*\.?\w+))/gi;
    return Array.from(style.matchAll(regex), (match) => [match[2], trimWhitespace(match[5])]);
  }

  /** Attribute + style values for the given names; style wins, as it is applied last here. */
  function collectAttributes(element, names) {
    const values = {};
    for (const name of names) {
      const value = attribute(element, name);
      if (value !== null) values[name] = value;
    }
    const style = attribute(element, 'style');
    if (style !== null) {
      for (const [name, value] of styleDeclarations(style)) {
        if (names.includes(name)) values[name] = value;
      }
    }
    return values;
  }

  function applyStrokeStyle(layer, values) {
    if ('stroke-linecap' in values) layer.lineCap = LINE_CAPS.has(values['stroke-linecap']) ? values['stroke-linecap'] : 'butt';
    if ('stroke-linejoin' in values) layer.lineJoin = LINE_JOINS.has(values['stroke-linejoin']) ? values['stroke-linejoin'] : 'miter';
    if ('stroke-miterlimit' in values) {
      const miterLimit = swiftDouble(values['stroke-miterlimit']);
      if (miterLimit !== null) layer.miterLimit = miterLimit;
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Document walk — mirrors NSXMLSVGParser's element stack.

  function parse(svgText) {
    const fatal = [];
    const warnings = new Set();
    const issues = {
      fatal: (message) => fatal.push(message),
      warn: (message) => warnings.add(message),
    };

    const roots = [];
    const shapes = [];
    let boundingBox = null;
    let viewBox = null;
    let shapeCount = 0;
    const result = () => ({ ok: fatal.length === 0, fatal, warnings: Array.from(warnings), boundingBox, viewBox, shapes });

    const doc = new DOMParser().parseFromString(svgText, 'image/svg+xml');
    const parserError = doc.getElementsByTagName('parsererror')[0];
    if (parserError) {
      issues.fatal(`The file is not well-formed XML, so SwiftSVG renders nothing: ${parserError.textContent.trim().split('\n')[0]}`);
      return result();
    }

    const visit = (element, top) => {
      const tag = element.tagName;

      if (!SUPPORTED_TAGS.has(tag)) {
        if (SHAPES_RENDERED_INSIDE.has(tag) && hasShapeDescendant(element)) {
          issues.warn(`Shapes inside <${tag}> are drawn by SwiftSVG as regular outline strokes.`);
        } else if (!SILENTLY_IGNORED_TAGS.has(tag)) {
          issues.warn(`<${tag}> is not supported by SwiftSVG and is skipped (its children are still parsed).`);
        }
        for (const child of elementChildren(element)) visit(child, top);
        return;
      }

      if (tag === 'svg') {
        const root = { kind: 'root', offset: { x: 0, y: 0 }, children: [] };
        const rawViewBox = attribute(element, 'viewBox');
        if (rawViewBox !== null) {
          const values = rawViewBox.split(/[, ]/).map((v) => swiftDouble(trimWhitespace(v))).filter((v) => v !== null);
          if (values.length === 4) {
            root.offset = { x: values[0], y: values[1] };
            if (!viewBox) viewBox = { x: values[0], y: values[1], width: values[2], height: values[3] };
          }
        }
        if (top) issues.warn('Nested <svg> elements are hoisted to the top level by SwiftSVG (ancestor transforms are dropped).');
        for (const child of elementChildren(element)) visit(child, root);
        roots.push(root);
        return;
      }

      const topIsContainer = top && (top.kind === 'root' || top.kind === 'group');

      if (tag === 'g') {
        const group = { kind: 'group', transform: IDENTITY, children: [] };
        const transform = attribute(element, 'transform');
        if (transform !== null) group.transform = parseTransform(transform);

        for (const child of elementChildren(element)) visit(child, group);
        if (!topIsContainer) return;

        // SVGGroup.didProcessElement: delayed attributes land on direct shape children only.
        const delayed = collectAttributes(element, ['opacity', 'fill-opacity', 'stroke-linecap', 'stroke-linejoin', 'stroke-miterlimit']);
        const opacityValue = 'fill-opacity' in delayed ? delayed['fill-opacity'] : delayed.opacity;
        for (const child of group.children) {
          if (child.kind !== 'shape') continue;
          applyStrokeStyle(child, delayed);
          if (opacityValue !== undefined) {
            const opacity = swiftDouble(opacityValue);
            if (opacity !== null) child.opacity = opacity;
          }
        }
        top.children.push(group);
        return;
      }

      // Shapes
      if (tag === 'path' && attribute(element, 'd') === null) {
        issues.fatal('A <path> has no d attribute: SwiftSVG waits for it forever and never delivers the outline.');
      }
      const path = shapePath(element, tag, issues);
      const shape = {
        kind: 'shape',
        tag,
        path,
        transform: IDENTITY,
        lineCap: 'butt',
        lineJoin: 'miter',
        miterLimit: 10,
        opacity: 1,
      };
      const transform = attribute(element, 'transform');
      if (transform !== null) shape.transform = parseTransform(transform);
      applyStrokeStyle(shape, collectAttributes(element, ['stroke-linecap', 'stroke-linejoin', 'stroke-miterlimit']));

      for (const child of elementChildren(element)) visit(child, shape);

      const shapeBounds = path ? path.boundingBox() : null;
      if (topIsContainer) {
        top.children.push(shape);
        boundingBox = unionRect(boundingBox, shapeBounds);
        shapeCount += 1;
      } else if (tag === 'path') {
        // Paths report their bounds from the async parse callback even when they are never attached.
        boundingBox = unionRect(boundingBox, shapeBounds);
      }
    };

    visit(doc.documentElement, null);

    // Flatten into drawable shapes with their transform into SVGLayer space.
    const flatten = (layer, parentTransform) => {
      for (const child of layer.children) {
        if (child.kind === 'group') {
          flatten(child, concat(child.transform, parentTransform));
        } else if (child.path && child.path.elements.length > 0) {
          shapes.push({
            tag: child.tag,
            d: child.path.toSVGPathData(),
            transform: concat(child.transform, parentTransform),
            lineCap: child.lineCap,
            lineJoin: child.lineJoin,
            miterLimit: child.miterLimit,
            opacity: Math.min(1, Math.max(0, child.opacity)),
          });
        }
      }
    };
    for (const root of roots) flatten(root, translation(root.offset.x, root.offset.y));

    if (shapeCount === 0 && fatal.length === 0) issues.warn('No drawable shapes were found.');
    if (boundingBox && (boundingBox.x !== 0 || boundingBox.y !== 0)) {
      const at = `(${+boundingBox.x.toFixed(2)}, ${+boundingBox.y.toFixed(2)})`;
      warnings.add(`The paths' bounding box starts at ${at}, not (0, 0). resizeToFit only scales, so the outline is drawn offset from the box origin by scale × ${at}.`);
    }
    if (viewBox && (viewBox.x !== 0 || viewBox.y !== 0)) {
      warnings.add(`viewBox starts at (${viewBox.x}, ${viewBox.y}): SwiftSVG shifts the drawing by +(${viewBox.x}, ${viewBox.y}) instead of −.`);
    }

    return result();
  }

  // ---------------------------------------------------------------------------------------------
  // ZTronSVGView / SVGLayer placement

  /** `SVGLayerType.resizeToFit(_:)`: aspect-fit scale factor only; the rect origin is ignored. */
  function resizeToFitScale(boundingBox, rectWidth, rectHeight) {
    const boundingBoxAspectRatio = boundingBox.width / boundingBox.height;
    const viewAspectRatio = rectWidth / rectHeight;
    return boundingBoxAspectRatio > viewAspectRatio ? rectWidth / boundingBox.width : rectHeight / boundingBox.height;
  }

  /** `ZTronSVGView.maxLineWidth`, from the descriptor's normalized AABB. */
  function maxLineWidth(normalizedAABB) {
    return Math.hypot(normalizedAABB.width, normalizedAABB.height) >= 0.07 ? 7.5 : 37.0;
  }

  /** `ZTronSVGView.updateForZoom(_:)` with the carousel's 1…20 zoom range. */
  function lineWidthForZoom(normalizedAABB, zoomScale, minimumZoomScale = 1, maximumZoomScale = 20) {
    const MIN_LINE_WIDTH = 5;
    const max = maxLineWidth(normalizedAABB);
    if (zoomScale <= minimumZoomScale) return max; // updateForZoom only runs once the user zooms
    const t = 1 - (zoomScale - minimumZoomScale) / (maximumZoomScale - minimumZoomScale);
    return Math.max(MIN_LINE_WIDTH, MIN_LINE_WIDTH + t * (max - MIN_LINE_WIDTH));
  }

  /** `CGSize.sizeThatFits(containerSize:containedAR:)`. */
  function sizeThatFits(containerWidth, containerHeight, aspectRatio) {
    if (containerWidth / containerHeight >= aspectRatio) {
      return { width: containerHeight * aspectRatio, height: containerHeight };
    }
    return { width: containerWidth, height: containerWidth / aspectRatio };
  }

  const api = {
    parse,
    resizeToFitScale,
    maxLineWidth,
    lineWidthForZoom,
    sizeThatFits,
    concat,
    translation,
    scaling,
    applyTransform,
    _internals: { lexPathData, lexPoints, parseTransform, pathFromD, strtodBytes, swiftDouble, CGPath },
  };

  if (typeof module === 'object' && module.exports) module.exports = api;
  else global.SwiftSVG = api;
})(typeof window !== 'undefined' ? window : globalThis);
