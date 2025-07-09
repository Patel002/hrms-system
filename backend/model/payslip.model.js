import { sequelize } from "../database/db.js";
import { DataTypes } from "sequelize";

const PaySlip = sequelize.define('payslip',{
    id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    emp_id: {
        type: DataTypes.INTEGER,
        allowNull: false,
    },
    company_id: {
        type: DataTypes.INTEGER,
        allowNull: false,
    },
    salarydate: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    paid_date: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    diduction_pattern: {
        type: DataTypes.STRING,
        allowNull: false
    }
    },
    {
        tableName: 't_salary',
        timestamps: false
    })

export default PaySlip;