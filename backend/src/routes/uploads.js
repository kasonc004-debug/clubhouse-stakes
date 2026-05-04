const router = require('express').Router();
const { requireAuth } = require('../middleware/auth');
const { uploader, uploadImage } = require('../controllers/uploadController');

// multer errors arrive synchronously (e.g. file size) — bubble them as 4xx.
function handleMulter(req, res, next) {
  uploader.single('image')(req, res, err => {
    if (!err) return next();
    const status = err.code === 'LIMIT_FILE_SIZE' ? 413 : 422;
    return res.status(status).json({ error: err.message });
  });
}

router.post('/image', requireAuth, handleMulter, uploadImage);

module.exports = router;
