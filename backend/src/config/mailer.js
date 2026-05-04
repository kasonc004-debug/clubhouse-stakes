// Thin wrapper around nodemailer.
// If SMTP env vars are unset, sendMail() logs the message instead of sending —
// keeps dev workflow unblocked without configuration.

const nodemailer = require('nodemailer');

let transporter = null;
function getTransporter() {
  if (transporter) return transporter;
  const host = process.env.SMTP_HOST;
  if (!host) return null;
  transporter = nodemailer.createTransport({
    host,
    port: parseInt(process.env.SMTP_PORT, 10) || 587,
    secure: (parseInt(process.env.SMTP_PORT, 10) || 587) === 465,
    auth: process.env.SMTP_USER
      ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
      : undefined,
  });
  return transporter;
}

const FROM = () => process.env.EMAIL_FROM ||
  'Clubhouse Stakes <no-reply@clubhousestakes.com>';

async function sendMail({ to, subject, text, html }) {
  const t = getTransporter();
  if (!t) {
    console.log('[mailer] SMTP not configured — logging invite instead:');
    console.log('  to:     ', to);
    console.log('  subject:', subject);
    console.log('  text:   ', text);
    return { logged: true };
  }
  try {
    const info = await t.sendMail({ from: FROM(), to, subject, text, html });
    return { messageId: info.messageId };
  } catch (err) {
    console.error('[mailer] send failed:', err.message);
    return { error: err.message };
  }
}

module.exports = { sendMail };
