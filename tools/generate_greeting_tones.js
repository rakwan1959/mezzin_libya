// مولد نغمات كارد الرسالة — يولّد ملفين صوتيين مضمّنين في التطبيق:
//   greeting_chime.wav : رنّة مزدوجة هادئة (نوتتان صاعدتان)
//   greeting_bell.wav  : جرس ثلاثي قصير (ثلاث نوتات صاعدة)
//
// نغمات نقيّة (جيبية) بلا موسيقى، مع تلاشٍ ناعم في النهاية لمنع الطقطقة.
// تُكتب في مكانين لأن مسار Flutter لا يصل إليه MediaPlayer الأصلي:
//   assets/audio/                      (لـ just_audio داخل التطبيق)
//   android/app/src/main/res/raw/      (لـ MediaPlayer في MainActivity)
//
// التشغيل:  node tools/generate_greeting_tones.js
const fs = require('fs');
const path = require('path');

const SAMPLE_RATE = 22050;
const PEAK = 0.42; // هادئة عمداً: رسالة ترحيب لا منبّه

/// يولّد قناة واحدة 16-bit PCM من قائمة نوتات {freq, start, dur}.
function renderNotes(notes, totalSeconds) {
  const total = Math.round(totalSeconds * SAMPLE_RATE);
  const samples = new Float32Array(total);
  for (const note of notes) {
    const start = Math.round(note.start * SAMPLE_RATE);
    const length = Math.round(note.dur * SAMPLE_RATE);
    for (let i = 0; i < length && start + i < total; i++) {
      const t = i / SAMPLE_RATE;
      // هجوم سريع 6ms ثم تلاشٍ أسّي هادئ
      const attack = Math.min(1, t / 0.006);
      const decay = Math.exp(-3.4 * (t / note.dur));
      const envelope = attack * decay;
      const wave =
        Math.sin(2 * Math.PI * note.freq * t) +
        0.28 * Math.sin(2 * Math.PI * note.freq * 2 * t); // لمعة خفيفة
      samples[start + i] += wave * envelope * PEAK;
    }
  }
  // تلاشٍ نهائي 40ms + قصّ عند ±1
  const fade = Math.round(0.04 * SAMPLE_RATE);
  for (let i = 0; i < fade; i++) {
    const idx = total - fade + i;
    if (idx >= 0) samples[idx] *= 1 - i / fade;
  }
  for (let i = 0; i < total; i++) {
    samples[i] = Math.max(-1, Math.min(1, samples[i]));
  }
  return samples;
}

function encodeWav(samples) {
  const dataBytes = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataBytes);
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataBytes, 4);
  buffer.write('WAVE', 8);
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16); // حجم كتلة fmt
  buffer.writeUInt16LE(1, 20); // PCM
  buffer.writeUInt16LE(1, 22); // أحادي
  buffer.writeUInt32LE(SAMPLE_RATE, 24);
  buffer.writeUInt32LE(SAMPLE_RATE * 2, 28); // بايت/ثانية
  buffer.writeUInt16LE(2, 32); // محاذاة الكتلة
  buffer.writeUInt16LE(16, 34); // بت/عيّنة
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataBytes, 40);
  for (let i = 0; i < samples.length; i++) {
    buffer.writeInt16LE(Math.round(samples[i] * 32767), 44 + i * 2);
  }
  return buffer;
}

const tones = {
  // نوتتان صاعدتان — الصوت المميّز لكارد الرسالة
  greeting_chime: {
    notes: [
      { freq: 880.0, start: 0.0, dur: 0.62 }, // A5
      { freq: 1318.5, start: 0.34, dur: 1.05 }, // E6
    ],
    total: 1.6,
  },
  // جرس ثلاثي صاعد — بديل أخفّ
  greeting_bell: {
    notes: [
      { freq: 659.25, start: 0.0, dur: 0.5 }, // E5
      { freq: 987.77, start: 0.26, dur: 0.6 }, // B5
      { freq: 1318.5, start: 0.52, dur: 1.0 }, // E6
    ],
    total: 1.7,
  },
};

const destinations = [
  path.join(__dirname, '..', 'assets', 'audio'),
  path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res', 'raw'),
];

for (const [name, spec] of Object.entries(tones)) {
  const wav = encodeWav(renderNotes(spec.notes, spec.total));
  for (const dir of destinations) {
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, `${name}.wav`);
    fs.writeFileSync(file, wav);
    console.log(`wrote ${file} (${wav.length} bytes)`);
  }
}
