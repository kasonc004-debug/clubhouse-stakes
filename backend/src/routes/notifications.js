const router = require('express').Router();
const { requireAuth } = require('../middleware/auth');
const ctrl = require('../controllers/notificationController');

router.get('/',                requireAuth, ctrl.listMine);
router.post('/read-all',       requireAuth, ctrl.markAllRead);
router.post('/:id/read',       requireAuth, ctrl.markRead);

module.exports = router;
