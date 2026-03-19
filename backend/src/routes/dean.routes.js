const express        = require("express");
const router         = express.Router();
const authMiddleware = require("../middleware/auth.middleware");
const roleMiddleware = require("../middleware/role.middleware");

const {
  getDeanStats,
  getDeanCourses,
  getDeanStudents,
  getDeanLecturers,
} = require("../controllers/dean.controller");

// All dean routes require a valid JWT AND the "dean" role
router.use(authMiddleware);
router.use(roleMiddleware("dean"));

router.get("/stats",     getDeanStats);
router.get("/courses",   getDeanCourses);
router.get("/students",  getDeanStudents);
router.get("/lecturers", getDeanLecturers);

module.exports = router;