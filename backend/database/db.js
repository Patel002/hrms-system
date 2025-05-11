import { Sequelize } from "sequelize";

const sequelize = new Sequelize(
    process.env.DB_DATABASENAME,
    process.env.DB_USERNAME,
    process.env.DB_PASSWORD,
    {
        host: process.env.DB_HOST,
        dialect: 'mysql',
        port: 3306
    }
)

export {sequelize};