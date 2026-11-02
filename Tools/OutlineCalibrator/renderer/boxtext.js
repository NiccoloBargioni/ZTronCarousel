/*
 * Reading and writing bounding boxes as text.
 *
 * Accepted input, for example:
 *   boundingBox: .init(x: 1939.0 / 3840.0, y: 1715.0 / 2160.0, width: 384.83712 / 3840.0, height: 248.28336 / 2160.0)
 *   CGRect(origin: CGPoint(x: 0.5, y: 0.4), size: CGSize(width: 0.1, height: 0.2))
 *   0.5, 0.4, 0.1, 0.2        (normalized)
 *   1939, 1715, 384.8, 248.3  (pixels: divided by the known reference size)
 *
 * Labeled arguments are evaluated as arithmetic (+ − * /, parentheses, wrappers such as CGFloat(…)).
 * When an argument is a division, its divisor is taken as the reference size for that axis.
 */
(function (global) {
  'use strict';

  const KEYS = ['x', 'y', 'width', 'height'];
  const NUMBER = /[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/iy;

  /** Evaluates an arithmetic expression. Returns { value, divisor } where divisor is set for `a / b`. */
  function evaluate(source) {
    let index = 0;

    const skipSpace = () => {
      while (index < source.length && /\s/.test(source[index])) index += 1;
    };
    const fail = (what) => {
      throw new SyntaxError(`${what} in "${source.trim()}"`);
    };

    function factor() {
      skipSpace();
      const character = source[index];
      if (character === '+' || character === '-') {
        index += 1;
        const inner = factor();
        return { value: character === '-' ? -inner.value : inner.value, divisor: inner.divisor };
      }
      if (character === '(') return group();

      const identifier = /[A-Za-z_][\w.]*/y;
      identifier.lastIndex = index;
      const name = identifier.exec(source);
      if (name) {
        // Swift wrappers like CGFloat(…) or Double(…): only the parenthesized value matters.
        index = identifier.lastIndex;
        skipSpace();
        if (source[index] !== '(') fail(`Unexpected name "${name[0]}"`);
        return group();
      }

      NUMBER.lastIndex = index;
      const match = NUMBER.exec(source);
      if (!match) fail('Expected a number');
      index = NUMBER.lastIndex;
      return { value: Number(match[0]), divisor: null };
    }

    function group() {
      index += 1; // (
      const inner = expression();
      skipSpace();
      if (source[index] !== ')') fail('Missing ")"');
      index += 1;
      return inner;
    }

    function term() {
      let result = factor();
      for (;;) {
        skipSpace();
        const operator = source[index];
        if (operator !== '*' && operator !== '/') return result;
        index += 1;
        const right = factor();
        result = operator === '*'
          ? { value: result.value * right.value, divisor: null }
          : { value: result.value / right.value, divisor: right.value };
      }
    }

    function expression() {
      let result = term();
      for (;;) {
        skipSpace();
        const operator = source[index];
        if (operator !== '+' && operator !== '-') return result;
        index += 1;
        const right = term();
        result = { value: operator === '+' ? result.value + right.value : result.value - right.value, divisor: null };
      }
    }

    const result = expression();
    skipSpace();
    if (index < source.length) fail(`Unexpected "${source[index]}"`);
    if (!Number.isFinite(result.value)) fail('Not a finite number');
    return result;
  }

  /** The text of `key: …` up to the next top-level comma or closing bracket. */
  function labeledArgument(text, key) {
    const label = new RegExp(`(?<![\\w.])${key}\\s*:`, 'g');
    const match = label.exec(text);
    if (!match) return null;
    const afterMatch = label.lastIndex;
    if (label.exec(text)) throw new SyntaxError(`"${key}:" appears more than once. Paste a single box.`);
    label.lastIndex = afterMatch;
    let depth = 0;
    let end = label.lastIndex;
    for (; end < text.length; end += 1) {
      const character = text[end];
      if (character === '(' || character === '[') depth += 1;
      else if (character === ')' || character === ']') {
        if (depth === 0) break;
        depth -= 1;
      } else if (character === ',' && depth === 0) break;
    }
    return text.slice(label.lastIndex, end);
  }

  /** Reads four values (and their divisors, if written as fractions) from free-form text. */
  function read(text) {
    const labeled = KEYS.map((key) => labeledArgument(text, key));
    if (labeled.every((argument) => argument !== null)) {
      const results = labeled.map(evaluate);
      return {
        values: Object.fromEntries(KEYS.map((key, i) => [key, results[i].value])),
        divisors: Object.fromEntries(KEYS.map((key, i) => [key, results[i].divisor])),
      };
    }
    if (labeled.some((argument) => argument !== null)) {
      const missing = KEYS.filter((_, i) => labeled[i] === null);
      throw new SyntaxError(`Missing ${missing.join(', ')}`);
    }

    // Unlabeled: four numbers, each optionally written as a / b.
    const tokens = text.match(/[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?|\//gi) || [];
    const terms = [];
    for (let i = 0; i < tokens.length && terms.length < 4; i += 1) {
      if (tokens[i] === '/') continue;
      if (tokens[i + 1] === '/' && tokens[i + 2] !== undefined && tokens[i + 2] !== '/') {
        const divisor = Number(tokens[i + 2]);
        terms.push({ value: Number(tokens[i]) / divisor, divisor });
        i += 2;
      } else {
        terms.push({ value: Number(tokens[i]), divisor: null });
      }
    }
    if (terms.length < 4) throw new SyntaxError('Expected four values: x, y, width, height');
    return {
      values: Object.fromEntries(KEYS.map((key, i) => [key, terms[i].value])),
      divisors: Object.fromEntries(KEYS.map((key, i) => [key, terms[i].divisor])),
    };
  }

  /** One divisor per axis: x/width share the horizontal one, y/height the vertical one. */
  function axisDivisor(a, b) {
    if (a !== null && b !== null && Math.abs(a - b) > 1e-9 * Math.max(Math.abs(a), Math.abs(b))) return NaN;
    return a ?? b;
  }

  /**
   * Turns text into a normalized box.
   * @param {string} text
   * @param {{width: number, height: number} | null} referenceSize used for plain pixel values
   * @returns {{ box, kind: 'fractions' | 'normalized' | 'pixels', detectedSize, note }}
   */
  function parse(text, referenceSize) {
    const { values, divisors } = read(text);

    if (KEYS.some((key) => divisors[key] !== null)) {
      const width = axisDivisor(divisors.x, divisors.width);
      const height = axisDivisor(divisors.y, divisors.height);
      let detectedSize = null;
      let note = null;
      if (Number.isNaN(width) || Number.isNaN(height)) {
        note = 'x/width or y/height use different divisors, so no size was detected.';
      } else if (width !== null && height !== null) {
        detectedSize = { width, height };
      } else {
        note = 'Only one axis is written as a fraction, so no size was detected.';
      }
      return { box: values, kind: 'fractions', detectedSize, note };
    }

    if (KEYS.every((key) => values[key] >= 0 && values[key] <= 1)) {
      return { box: values, kind: 'normalized', detectedSize: null, note: null };
    }

    if (!referenceSize) {
      throw new Error('These look like pixel values. Load an image or paste fractions such as x: 1939.0 / 3840.0 so the size is known.');
    }
    return {
      box: {
        x: values.x / referenceSize.width,
        y: values.y / referenceSize.height,
        width: values.width / referenceSize.width,
        height: values.height / referenceSize.height,
      },
      kind: 'pixels',
      detectedSize: null,
      note: null,
    };
  }

  /** A Swift Double literal: `1939.0`, `384.83712`. */
  function swiftLiteral(value) {
    const rounded = +value.toFixed(5);
    return Number.isInteger(rounded) ? rounded.toFixed(1) : String(rounded);
  }

  /** One argument value: a fraction of `size` when one is known (`1939.0 / 3840.0`), else normalized. */
  function formatArgument(box, key, size) {
    if (!size) return box[key].toFixed(6);
    const dimension = key === 'x' || key === 'width' ? size.width : size.height;
    return `${swiftLiteral(box[key] * dimension)} / ${swiftLiteral(dimension)}`;
  }

  /** Formats a normalized box like the input example: `boundingBox: .init(x: …, y: …, width: …, height: …)`. */
  function formatInit(box, size, { multiline = true } = {}) {
    const items = KEYS.map((key) => `${key}: ${formatArgument(box, key, size)}`);
    return multiline
      ? `boundingBox: .init(\n${items.map((item) => `    ${item}`).join(',\n')}\n)`
      : `boundingBox: .init(${items.join(', ')})`;
  }

  const api = { parse, formatInit, formatArgument, KEYS, _internals: { evaluate, read } };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else global.BoxText = api;
})(typeof window !== 'undefined' ? window : globalThis);
