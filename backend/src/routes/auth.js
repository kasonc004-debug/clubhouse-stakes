const router = require('express').Router();
const { body } = require('express-validator');
const ctrl = require('../controllers/authController');
const { requireAuth } = require('../middleware/auth');

router.post('/signup',
  body('name').trim().notEmpty(),
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 8 }),
  ctrl.signup
);

router.post('/login',
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
  ctrl.login
);

router.post('/apple', ctrl.appleSignIn);

router.get('/me',    requireAuth, ctrl.getMe);
router.patch('/me',  requireAuth, ctrl.updateMe);

module.exports = router;
