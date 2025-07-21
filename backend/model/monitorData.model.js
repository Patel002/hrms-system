import { sequelize } from  '../database/db.js';
import { DataTypes } from 'sequelize';

const MonitorData = sequelize.define('monitordatatbl', {
    id:{
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true
    },
    SRNO:{
        type: DataTypes.STRING,
        allowNull: false
    },
    EnrollID:{
        type: DataTypes.INTEGER,
        allowNull: false
    },
    PunchDate:{
        type: DataTypes.DATE,
        allowNull: false,
    },
    Received_date:{
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    verifyMode:{
        type: DataTypes.STRING,
        allowNull: false
    },
    TRID:{
        type: DataTypes.STRING,
        allowNull: true,
        defaultValue: 0
    },
    Temperature_c:{
        type: DataTypes.INTEGER,
        defaultValue: 0
    },
    Temperature_f:{
        type: DataTypes.INTEGER,
        defaultValue: 0
    }
},{
    tableName: 'monitordatatbl',
    timestamps: false   
})

export default MonitorData;