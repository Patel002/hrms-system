import { sequelize } from "../database/db.js";
import { DataTypes } from "sequelize";

const Employee = sequelize.define('employee',{
    id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    em_id: {
        type: DataTypes.STRING,
        allowNull: false
    },
    em_username: {
        type: DataTypes.STRING,
        allowNull: false
    },
    em_code: {
        type: DataTypes.STRING,
        allowNull: false
    },
    dep_id: {
        type: DataTypes.STRING,
    },
    supervisor_id: {
        type: DataTypes.INTEGER,
    },
    em_email: {
        type: DataTypes.STRING,
        allowNull: false
    },
    em_role: {
        type: DataTypes.STRING,
        allowNull: false
    },
    reporting_auth:{
        type: DataTypes.BOOLEAN,
    }

},{
    tableName: 'employee',
    timestamps: false
})

export default Employee;