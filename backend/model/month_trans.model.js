import { sequelize } from '../database/db.js';
import { DataTypes } from 'sequelize';

const MonthTrans = sequelize.define('month_trans',{
    
    id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    attcode: {
        type: DataTypes.STRING,
        allowNull: false
    },
    emp_id: {
        type: DataTypes.INTEGER,
        allowNull: false
    },
    master_shift: {
        type: DataTypes.STRING,
        allowNull: false
    },
    othrs: {
        type: DataTypes.DECIMAL(4,2),
        allowNull: false
    },
    otminutes: {
        type: DataTypes.DECIMAL(4,2),
        allowNull: false
    },
    wrkhrs: {
        type: DataTypes.DECIMAL(4,2),
        allowNull: false
    },
    presabs: {
        type: DataTypes.CHAR(1),
        allowNull: false
    },
    punchin: {
        type: DataTypes.DATE,
        allowNull: false
    },
    punchout: {
        type: DataTypes.DATE,
        allowNull: false
    },
    agencyid: {
        type: DataTypes.STRING,
        allowNull: false
    },
    designation: {
        type: DataTypes.STRING,
        allowNull: false
    },
    trndate: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    capproval: {
        type: DataTypes.STRING,
        allowNull: false
    }
},
{
    tableName: 'month_trans',
    timestamps: false   
})

export {MonthTrans};