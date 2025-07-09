import { sequelize } from "../database/db.js";
import { DataTypes } from "sequelize";

const EmployeeLeaveBalance = sequelize.define('employee_leave_balance',{
    employee_leave_balance_id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    request_id: {
        type: DataTypes.STRING,
    },
    emp_id: {
        type: DataTypes.STRING,
        allowNull: false
    },
    leave_type_id: {
        type: DataTypes.INTEGER,
        allowNull: false
    },
    number_of_days: {
        type: DataTypes.FLOAT,
        allowNull: false
    },
    add_date: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    leave_status: {
        type: DataTypes.STRING,
        allowNull: false
    },
    leave_upload_date: {
        type: DataTypes.DATEONLY,
        allowNull: false
    }
},{
    tableName: 'employee_leave_balance',
    timestamps: false
})

export default EmployeeLeaveBalance;