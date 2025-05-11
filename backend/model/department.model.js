import { sequelize } from "../database/db.js";
import { DataTypes } from "sequelize";

const Department = sequelize.define('department',{
    id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    dep_code: {
        type: DataTypes.STRING,
        allowNull: false
    },
    dep_name: {
        type: DataTypes.STRING,
        allowNull: false
    },
    updated_by: {
        type: DataTypes.STRING
    }
},{
    tableName: 'department',
    timestamps: false
})

export default Department;