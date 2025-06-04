import { Sequelize } from "sequelize";

const sequelize = new Sequelize(
    'u905741255_anishpharma0',
    'u905741255_anishpharma0',
    '9q3>pZEA*Vt',
    {
        host: '151.106.122.3',
        dialect: 'mysql',
        port: 3306,
        logging: false
    }
)

export {sequelize};