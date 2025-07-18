import { sequelize } from  '../database/db.js';
import { DataTypes } from 'sequelize';

const OdPass = sequelize.define('od_pass',{
   id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    emp_id: {
        type: DataTypes.STRING,
        allowNull: false
    },
    comp_id: {
        type: DataTypes.STRING,
        allowNull: false
    },
    add_date: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    fromdate:{
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    todate: {
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    oddays:{
        type: DataTypes.DECIMAL(4,2),
        allowNull: false
    },
    odtype:{
        type: DataTypes.INTEGER,
        allowNull: false
    },
    remark: {
        type: DataTypes.TEXT,
        allowNull: false
    },
    created_at: {
        type: DataTypes.DATE,
        allowNull: false
    },
    approved: {
        type: DataTypes.ENUM('APPROVED','PENDING','REJECTED'),
        allowNull: false,
        defaultValue: 'PENDING'
    },
    app_type:{
        type: DataTypes.ENUM('OD','TOUR'),
        allowNull: false,
        defaultValue: 'OD'
    },
    status:{
        type: DataTypes.ENUM('0','1'),
        allowNull: false,
        defaultValue: '1'
    },
    updated_by:{
       type: DataTypes.STRING,
    },
    updated_at:{
        type: DataTypes.DATE,
    },
    created_by:{
        type: DataTypes.STRING,
        allowNull: false
    },
    approved_by: {
        type: DataTypes.STRING
    },
    approved_at: {
        type: DataTypes.DATE
    },
    approve_step1:{
        type: DataTypes.ENUM('0','1'),
        allowNull: false,
        defaultValue: '0'
    },
    rejectreason: {
        type: DataTypes.STRING  
    }

},{
    tableName:'od_pass',
    timestamps: false
})

export default OdPass;
