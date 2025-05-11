import { sequelize } from "../database/db.js";
import { DataTypes } from "sequelize";

const LeaveTypes = sequelize.define('leave_types',{
    type_id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    name: {
        type: DataTypes.STRING,
        allowNull: false
    },
    leave_short_name: {
        type: DataTypes.STRING,
        allowNull: false
    },
    balance: {
        type: DataTypes.INTEGER,
        allowNull: false
    }
},{
    tableName: 'leave_types',
    timestamps: false
})

export default LeaveTypes;