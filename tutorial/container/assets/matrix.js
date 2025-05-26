#!/usr/bin/env node

import { rgb, greenBright, blueBright, bgBlack, whiteBright } from 'ansis'

const showCursor = () => {
  process.stderr.write('\x1B[?25h')
}

const hideCursor = () => {
  process.stderr.write('\x1B[?25l')
}

const pause = async (ms) => {
  return new Promise((resolve) => setTimeout(() => resolve(), ms))
}

const write = (x, y, text, color = blueBright, force = false) => {
  const { rows, columns } = process.stdout
  if (x >= columns || y >= rows) {
    return
  }

  if (x < 0 || y < 0) {
    return
  }

  /* do not draw under the date-time */
  if (
    !force &&
    x >= state.dateTime.x &&
    x <= state.dateTime.x + state.dateTime.str.length - 1 &&
    y === state.dateTime.y
  ) {
    return
  }

  /* do not draw under the quote */
  if (
    !force &&
    y === state.quote.y &&
    x >= state.quote.x -1 && // Check from one char before quote starts
    // Use pre-calculated maxPossibleLen to avoid drawing over the quote area
    x <= state.quote.x + state.quote.maxPossibleLen -1 // Check up to end of max quote length
  ) {
    return
  }


  process.stdout.cursorTo(x, y)

  const colors = Array.isArray(color) ? color : [color]
  colors.unshift(bgBlack) // Ensure background is black for text
  const coloredText = colors.reduce((prev, c) => {
    return c`${prev}`
  }, text)

  process.stdout.write(coloredText)
}

const random = (start, end) => {
  return Math.floor(Math.random() * (end - start)) + start
}

const randomElement = (array) => {
  return array[random(0, array.length)]
}

const randomChar = () => {
  const chars =
    'abcdefghijklmnopqrstuvqxyzABCDEFGHIJKLMNOPQRSTUVQXYZ*@$&^%#+=スシエカキクケコサスセソソタツテナヘホロヵ'.split(
      '',
    )
  return randomElement(chars)
}

const now = () => new Date().getTime()

const nowSec = () => Math.floor(now() / 1000)

const randomWord = () => {
  const data = Array(random(3, 10))
    .fill('')
    .map((_) => randomChar())
    .join('')
  const y = -1 * data.length - random(0, 12) // Start above screen

  return {
    data,
    y,
    updateAt: now(), // Set to now so it can move/update on first relevant tick
  }
}

const padZero = (num) => String(num).padStart(2, '0')

const currentDateTime = () => {
  const date = new Date()
  const day = padZero(date.getDate())
  const month = padZero(date.getMonth() + 1)
  const year = padZero(date.getFullYear())
  const seconds = padZero(date.getSeconds())
  const minutes = padZero(date.getMinutes())
  const hours = padZero(date.getHours())

  return `${day}-${month}-${year} ${hours}:${minutes}:${seconds}`
}

const quotes = [
  'Wake up, Vanessa...',
  'The container has you',
  'Follow the riddles 🐰',
  'Everything that you know is in Flux',
  'You know what to do.'
]

const state = {
  tick: 50,
  allQuotesShown: false,
  columns: [],
  dateTime: {
    x: Math.floor(process.stdout.columns - currentDateTime().length),
    y: 0,
    value: nowSec(),
    str: currentDateTime(),
    green: 10,
    dc: 5,
  },
  quote: {
    index: 0,
    status: 'typing',
    value: ' ',
    updateAt: now() + 50,
    typeDt: 20,
    deleteDt: 40,
    x: 1,
    y: 1,
    cursor: {
      symbol: '█',
      dt: 500,
      updateAt: now(),
    },
    maxPossibleLen: 0, // Will be calculated and stored
  },
}
// Initialize maxPossibleLen for quote state early
state.quote.maxPossibleLen = quotes.length > 0 ? Math.max(...quotes.map(q => q.length)) + 2 : 2;


const typeQuote = () => {
  const { quote } = state;
  const _now = now();
  const color = rgb(0, 60, 255);
  const maxPossibleQuoteLen = state.quote.maxPossibleLen;


  let cursorIsCurrentlyVisible = quote.value.endsWith(quote.cursor.symbol);
  if (quote.cursor.updateAt < _now) {
    quote.cursor.updateAt = _now + quote.cursor.dt;
    const valueChars = quote.value.split('');
    const lastChar = valueChars.pop() || ' ';

    if (lastChar === quote.cursor.symbol) {
      quote.value = `${valueChars.join('')} `;
      cursorIsCurrentlyVisible = false;
    } else {
      quote.value = `${valueChars.join('')}${quote.cursor.symbol}`;
      cursorIsCurrentlyVisible = true;
    }
  }

  if (quote.updateAt < _now) {
    if (state.allQuotesShown) {
      if (quote.value.trim() !== '') {
         write(quote.x, quote.y, ' '.repeat(maxPossibleQuoteLen), bgBlack, true);
         quote.value = ' ';
      }
      return;
    }

    let textPart = quote.value;
    let actualCursorSymbolForAppending = ' ';

    if (cursorIsCurrentlyVisible) {
      textPart = quote.value.slice(0, -1);
      actualCursorSymbolForAppending = quote.cursor.symbol;
    } else if (quote.value.endsWith(' ')) {
      textPart = quote.value.slice(0, -1);
      actualCursorSymbolForAppending = ' ';
    }

    const currentFullQuoteText = quotes[quote.index];
    // Handle cases where currentFullQuoteText might be undefined even if index is technically in range (e.g. sparse array, though not here)
    // or if quote.index has gone past the end (should be caught by allQuotesShown but as a safeguard)
    if (!currentFullQuoteText && quote.index < quotes.length) {
        state.allQuotesShown = true; // Treat as end if quote is invalid
        write(quote.x, quote.y, ' '.repeat(maxPossibleQuoteLen), bgBlack, true);
        quote.value = ' ';
        return;
    }


    if (quote.status === 'typing') {
      quote.updateAt = _now + quote.typeDt;
      if (textPart.length < currentFullQuoteText.length) {
        textPart += currentFullQuoteText[textPart.length];
      } else {
        quote.status = 'deleting';
        quote.updateAt = _now + 3000;
      }
    } else if (quote.status === 'deleting') {
      quote.updateAt = _now + quote.deleteDt;
      if (textPart.length > 0) {
        textPart = textPart.slice(0, -1);
      } else {
        const deletedQuoteText = quotes[quote.index];
        const clearLength = Math.max(maxPossibleQuoteLen, ((deletedQuoteText && deletedQuoteText.length) || 0) + 2);
        write(quote.x, quote.y, ' '.repeat(clearLength), bgBlack, true);

        quote.index++;

        if (quote.index >= quotes.length) {
          state.allQuotesShown = true;
          quote.value = ' ';
          return;
        }

        quote.status = 'typing';
        textPart = '';
        actualCursorSymbolForAppending = quote.cursor.symbol;
        quote.cursor.updateAt = _now;
        quote.updateAt = _now + 500 + random(0, 500); // Shorter delay before next quote
      }
    }
    quote.value = `${textPart}${actualCursorSymbolForAppending}`;
  }

  if (!state.allQuotesShown || quote.value.trim() !== '') {
      const displayValue = quote.value;
      const padding = ' '.repeat(Math.max(0, maxPossibleQuoteLen - displayValue.length));
      write(quote.x, quote.y, `${displayValue}${padding}`, color, true);
  }
};


const init = () => {
  const { rows, columns } = process.stdout
  for (let i = 0; i < columns; i++) {
    for (let j = 0; j < rows; j++) {
      write(i, j, ` `, bgBlack, true) // Initial clear with black background
    }
  }

  for (let i = 0; i < columns / 2; i++) { // Create columns for matrix rain
    state.columns.push({
      // When this column might add a new word or change speed
      updateAt: now() + random(0, 4000),
      // Initial speed for words in this column
      speed: random(100, 500),
      // X position of the column (every other character cell)
      x: i * 2,
      words: [randomWord()],
    })
  }
  state.dateTime.x = Math.max(0, Math.floor(process.stdout.columns - currentDateTime().length -1));
  state.quote.maxPossibleLen = quotes.length > 0 ? Math.max(...quotes.map(q => q.length)) + 2 : 2; // Recalculate on init
}

const updateLastChar = (text) => {
  if (text.length === 0 || Math.random() < 0.9) { // 90% chance to NOT change
    return text
  }
  const chars = text.split('')
  chars[chars.length - 1] = randomChar() // Change the last character
  return chars.join('')
}

const changeRandomChars = (text) => {
  if (text.length === 0 || Math.random() < 0.95) { // 95% chance to NOT change
    return text
  }
  const length = text.length
  const n = Math.floor(Math.random() * (length / 3)) // Change up to 1/3 of characters
  const chars = text.split('')
  for (let i = 0; i < n; i++) {
    const j = Math.floor(Math.random() * length)
    chars[j] = randomChar()
  }
  return chars.join('')
}

const updateWord = (word, speed) => {
  // If it's not time to move the word down, DO NOTHING to its characters.
  if (word.updateAt > now()) {
    return word; // Return the word unchanged.
  }

  // It IS time to move the word down.
  const newY = word.y + 1;
  const { rows } = process.stdout;

  // Calculate L_calc: the length of the visible part of the word at its new position y.
  // This uses the original script's way of calculating the length for the slice operation.
  // word.data.length is the length of the character string from the *previous* step.
  const L_calc = Math.max(0, Math.min(newY + word.data.length, rows + 1) - newY);


  if (L_calc === 0 && newY >= 0) { // Word is off-screen or has no length
     return { ...word, y: newY, data: '', updateAt: now() + speed };
  }
  
  let stringToProcess = word.data;
  stringToProcess = changeRandomChars(stringToProcess); // Glitch characters in the current word segment

  // Form the new word segment:
  // (current_segment_body) + new_leader_char, then trim to L_calc length.
  // `slice(1)` removes the first char (oldest). `randomChar()` is the new leader.
  // `slice(1, L_calc + 1)` effectively shifts and ensures length is L_calc.
  let newSegmentData = (stringToProcess + randomChar()).slice(1, L_calc + 1);
  
  newSegmentData = updateLastChar(newSegmentData); // Glitch the new leader character

  return {
    ...word,
    data: newSegmentData,
    y: newY,
    updateAt: now() + speed,
  };
};


const updateColumn = (column) => {
  if (column.updateAt <= now()) {
    column.updateAt = now() + random(3000, 5000);

    if (random(0, 10) > 7) {
      column.speed = random(50, 500);
    }
    
    // Check if the topmost word in the column is sufficiently far down to add a new one.
    const topWord = column.words.length > 0 
        ? column.words.reduce((prev, curr) => (curr.y < prev.y ? curr : prev), { y: Infinity }) 
        : null; // Find word with smallest y

    if (!topWord || topWord.y > random(0, Math.floor(process.stdout.rows / 4))) { // Add new word if column empty or top word is down a bit
         column.words.push(randomWord());
    }
  }

  column.words = column.words
    .map((word) => updateWord(word, column.speed)) // Update each word in the column
    .filter(({ data }) => data && data.length > 0); // Remove words that are empty
};


const update = () => {
  state.columns.forEach((column) => {
    updateColumn(column);
  });
};

const charColor = (chars, i) => {
  const length = chars.length - 1;
  if (i === length) { // Last character is the leader
    return whiteBright;
  } else {
    // Gradually fade to darker green for older characters
    const greenIntensity = Math.max(Math.floor((180 / Math.max(length -1, 1)) * i) + 30, 30);
    return rgb(0, Math.min(greenIntensity, 220), 0); // Cap green to avoid too bright
  }
};

const drawWord = (x, word) => {
  // Clear the character cell that was directly above the word's new top position.
  // This is to erase the "ghost" of the first character from its previous frame.
  if (word.y -1 >= 0) {
     write(x, word.y - 1, ' '); // Write a space to clear
  }

  const chars = word.data.split('');
  chars.forEach((char, i) => {
    const yPos = word.y + i;
    // Draw only if the character is within the visible screen rows
    if (yPos >= 0 && yPos < process.stdout.rows) {
        const color = charColor(chars, i);
        write(x, yPos, char, color);
    }
  });
};

const draw = () => {
  state.columns.forEach((column) => {
    column.words.forEach((word) => drawWord(column.x, word));
  });
};

const drawDateTime = () => {
  const seconds = nowSec();
  if (state.dateTime.value < seconds) {
    state.dateTime.value = seconds;
    state.dateTime.str = currentDateTime();
    state.dateTime.x = Math.max(0, Math.floor(process.stdout.columns - state.dateTime.str.length -1));
  }

  state.dateTime.green += state.dateTime.dc;
  if (state.dateTime.green > 255) {
    state.dateTime.dc = -1 * state.dateTime.dc;
    state.dateTime.green = 255;
  }
  if (state.dateTime.green < 10) {
    state.dateTime.dc = -1 * state.dateTime.dc;
    state.dateTime.green = 50;
  }

  write(
    state.dateTime.x,
    state.dateTime.y,
    state.dateTime.str,
    [bgBlack, rgb(0, state.dateTime.green, 0)],
    true, // Force write
  );
};

const main = async () => {
  if (quotes.length === 0) {
    console.log("No quotes to display. Exiting.");
    showCursor();
    process.exit(0);
  }

  hideCursor();
  console.clear(); // Clear screen once at the very beginning
  init();

  while (!state.allQuotesShown) {
    await pause(state.tick);
    update();      // Update data for matrix and quotes
    draw();        // Draw matrix (drawWord handles clearing parts)
    drawDateTime();// Redraws datetime (force=true)
    if (quotes.length > 0) { // Guard for typeQuote
        typeQuote();   // Redraws quote (force=true)
    }
  }

  console.clear(); // Clear screen before exiting
  showCursor();
  process.exit(0);
};

process.on('SIGINT', () => {
  console.clear();
  showCursor();
  process.exit();
});

main();
