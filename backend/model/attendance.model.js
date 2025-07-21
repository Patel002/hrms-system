import { sequelize } from  '../database/db.js';
import { DataTypes } from 'sequelize';

const Attendance = sequelize.define('attendance_selfie', {
    id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    emp_id: {
        type: DataTypes.INTEGER,
        allowNull: false,
    },
    comp_id: {
        type: DataTypes.INTEGER,
        allowNull: false,
    },
    punch_date: {
        type: DataTypes.STRING,
        allowNull: false,
    },
    punch_time: {
        type: DataTypes.DATE,
        allowNull: false,
    },
    punch_place: {
        type: DataTypes.STRING,
        allowNull: false,
    },
    punchtype: {
        type: DataTypes.STRING,
        allowNull: false,
    },
    punch_remark: {
        type: DataTypes.STRING,
    },
    punch_img: {
        type: DataTypes.TEXT,
        allowNull: false,
    },
    latitude: {
        type: DataTypes.FLOAT,
        allowNull: false,
    },
    longitude: {
        type: DataTypes.FLOAT,
        allowNull: false,
    },
    created_by: {
        type: DataTypes.INTEGER,
        allowNull: false,
    },
    created_at: {
        type: DataTypes.DATE,
        allowNull: false,
        // defaultValue: DataTypes.NOW
    }
},{
    tableName: 'attendance_selfie',
    timestamps: false,
    // underscored: true
})

export default Attendance;