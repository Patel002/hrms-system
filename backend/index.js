import { sequelize } from './database/db.js';
import { app } from  './app.js';

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


