require("dotenv").config();

const connectDB = require("./src/config/db");
const app       = require("./src/app");

connectDB();

const PORT = process.env.PORT || 5000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Smart-Attend server running on port ${PORT}`);
});