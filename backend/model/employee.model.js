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
    },
    attcode: {
        type: DataTypes.INTEGER,
    },
    em_nid: {
        type: DataTypes.STRING,
    },
    pancard: {
        type: DataTypes.STRING,
    },
    em_joining_date: {
        type: DataTypes.DATE,
        // allowNull: false
    },
    em_gender: {
        type: DataTypes.ENUM('Male','Female'),
        // allowNull: false
    },
    father_name: {
        type: DataTypes.STRING,
    },
    last_name: {
        type: DataTypes.STRING,
    },
    first_name: {
        type: DataTypes.STRING,
        // allowNull: false
    },
    em_phone: {
        type: DataTypes.STRING,
        // allowNull: false
    },
    em_address: {
        type: DataTypes.STRING,
        // allowNull: false
    },
    em_blood_group: {
        type: DataTypes.STRING,
    },
    em_birthday: {
        type: DataTypes.DATEONLY,
        // allowNull: false
    },
    gst_number: {
        type: DataTypes.STRING,
    },
    updated_by: {
        type: DataTypes.STRING
    },
    updated_at: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW
    }

},{
    tableName: 'employee',
    timestamps: false
})

export default Employee;