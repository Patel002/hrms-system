import { sequelize } from "../database/db.js";
import { DataTypes } from "sequelize";

const EmployeeLeave = sequelize.define('emp_leave',{
    id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    em_id: {
        type: DataTypes.STRING,
        allowNull: false
    },
    leave_type: {
        type: DataTypes.STRING,
        allowNull: false
    },
    apply_date:{
        type: DataTypes.DATEONLY,
        allowNull:false
    },
    leave_status: {
        type: DataTypes.ENUM('Approve','Not Approve','Rejected'),
        allowNull: false
    },
    leave_duration: {
        type: DataTypes.DECIMAL(4,2),
        allowNull: false
    },
    comp_id: {
        type: DataTypes.STRING,
        allowNull: false
    },
    typeid: {
        type: DataTypes.STRING,
        allowNull: false
    },
    start_date: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    end_date: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    reason: {
        type: DataTypes.STRING,
        allowNull: false
    },
    leaveattachment: {
        type: DataTypes.STRING,
        allowNull: false
    },
    created_at: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    update_id: {
        type: DataTypes.DATE,
    },
    reject_reason: {
        type: DataTypes.STRING,
    },
    approved_by: {
        type: DataTypes.STRING,
    },
    approved_at: {
        type: DataTypes.DATE,
    }
},{
    tableName: 'emp_leave',
    timestamps: false
})

export default EmployeeLeave;
