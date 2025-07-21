import { sequelize } from "../database/db.js";
import { DataTypes } from "sequelize";

const Company = sequelize.define('company',{
    comp_fname: {
        type: DataTypes.STRING,
        allowNull: false
    },
    company_id: {
        type: DataTypes.STRING,
        // primaryKey: true
    },
    comp_id:{
        type: DataTypes.STRING,
    },
    comp_role: {
        type: DataTypes.STRING,
    }
},{
    tableName: 'company',
    timestamps: false
})

export default Company;