import { sequelize } from "../database/db.js";
import { DataTypes } from "sequelize";

const Department = sequelize.define('department',{
    id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    // dep_code: {
    //     type: DataTypes.STRING,
    //     allowNull: false
    // },
    dep_name: {
        type: DataTypes.STRING,
        allowNull: false
    },
    // company_id: {
    //     type: DataTypes.STRING,
    //     allowNull: false
    // }
},{
    tableName: 'm_department',
    timestamps: false
})

export default Department;