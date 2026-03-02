require("dotenv").config();
const connectDB = require("./src/config/db");
const app = require("./src/app");
const User = require("./src/models/User");

connectDB();

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
