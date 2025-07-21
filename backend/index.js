import { sequelize } from './database/db.js';
import { app } from  './app.js';
import dotenv from 'dotenv';
import cookieParser from 'cookie-parser';

dotenv.config();

app.use(cookieParser());

// console.log({
//   DB_DATABASENAME: process.env.DB_DATABASENAME,
//   DB_USERNAME: process.env.DB_USERNAME,
//   DB_PASSWORD: process.env.DB_PASSWORD,
//   DB_HOST: process.env.DB_HOST,
//   DB_PORT: process.env.DB_PORT,
// });


const PORT = 8071;

sequelize.authenticate()
  .then(() => console.log('Database connected...'))
  .catch(err => console.error('Unable to connect to DB:', err));

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

process.on('SIGINT', async () => {
  await sequelize.close();
  console.log('Database connection closed.');
  process.exit(0);
});


