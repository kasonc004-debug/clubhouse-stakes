const router = require('express').Router();
const ctrl   = require('../controllers/courseController');
const { requireAuth } = require('../middleware/auth');

// Course lookup is admin-flow only; require auth so we don't expose a
// proxy endpoint anyone can hammer with our API key.
router.get('/search', requireAuth, ctrl.searchCourses);
router.get('/:id',    requireAuth, ctrl.getCourse);

module.exports = router;
