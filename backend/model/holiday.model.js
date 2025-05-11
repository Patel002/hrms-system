import { sequelize } from "../database/db.js";
import { DataTypes } from "sequelize";

const holiday = sequelize.define('holiday',{
    id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    holiday_name: {
        type: DataTypes.STRING,
        allowNull: false
    },
    from_date: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    to_date: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    number_of_days: {
        type: DataTypes.INTEGER,
        allowNull: false
    },
    year: {
        type: DataTypes.INTEGER,
        allowNull: false
    },
    created_by: {
        type: DataTypes.STRING,
        allowNull: false
    }
},{
    tableName: 'holiday',
    timestamps: false
})

export default holiday;