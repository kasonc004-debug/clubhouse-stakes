const router = require('express').Router();
const ctrl   = require('../controllers/clubhouseController');
const { requireAuth, optionalAuth } = require('../middleware/auth');

router.get('/',          ctrl.listPublicClubhouses);
router.get('/mine', requireAuth, ctrl.listMyClubhouses);
router.get('/:slug', optionalAuth, ctrl.getClubhouseBySlug);
router.post('/',     requireAuth,  ctrl.createClubhouse);
router.patch('/:id', requireAuth,  ctrl.updateClubhouse);

// Membership
router.post('/:id/follow',         requireAuth, ctrl.followClubhouse);
router.delete('/:id/follow',       requireAuth, ctrl.unfollowClubhouse);
router.post('/:id/invite',         requireAuth, ctrl.inviteToClubhouse);
router.post('/:id/accept-invite',  requireAuth, ctrl.acceptInvite);

module.exports = router;
