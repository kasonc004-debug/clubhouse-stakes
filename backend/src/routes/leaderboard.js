const router = require('express').Router();
const ctrl   = require('../controllers/leaderboardController');

router.get('/best-rounds',          ctrl.getBestRounds);
router.get('/:tournament_id/skins', ctrl.getSkinsLeaderboard);
router.get('/:tournament_id',       ctrl.getLeaderboard);

module.exports = router;
