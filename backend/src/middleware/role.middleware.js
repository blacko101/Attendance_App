const roleMiddleware = (...allowedRoles) => {
  return (req, res, next) => {
    // Guard: req.user is set by authMiddleware. If roleMiddleware is ever
    // called on a route that doesn't have authMiddleware first, req.user
    // will be undefined and accessing .role would throw a TypeError.
    // This check makes the failure explicit and safe.
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        message: "You are not authorized to access this resource.",
      });
    }
    next();
  };
};

module.exports = roleMiddleware;