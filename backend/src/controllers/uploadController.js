const path   = require('path');
const fs     = require('fs');
const crypto = require('crypto');
const multer = require('multer');

const UPLOAD_DIR = path.join(__dirname, '../../uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: UPLOAD_DIR,
  filename:    (_req, file, cb) => {
    const ext = (path.extname(file.originalname) || '.jpg').toLowerCase();
    const id  = crypto.randomBytes(12).toString('hex');
    cb(null, `${Date.now()}-${id}${ext}`);
  },
});

const ALLOWED_MIMES = new Set([
  'image/jpeg', 'image/png', 'image/webp', 'image/gif',
]);

function fileFilter(_req, file, cb) {
  if (ALLOWED_MIMES.has(file.mimetype)) return cb(null, true);
  cb(new Error('Only JPEG, PNG, WebP or GIF images are allowed'));
}

const uploader = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
});

// POST /api/uploads/image  (multipart, field name "image")
async function uploadImage(req, res) {
  if (!req.file) return res.status(422).json({ error: 'No image uploaded' });
  // Construct an absolute URL so mobile clients can fetch it directly.
  const proto = req.headers['x-forwarded-proto'] || req.protocol;
  const host  = req.headers['x-forwarded-host']  || req.get('host');
  const url   = `${proto}://${host}/uploads/${req.file.filename}`;
  res.status(201).json({ url });
}

module.exports = { uploader, uploadImage };
