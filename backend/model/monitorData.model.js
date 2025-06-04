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
        type: DataTypes.DATEONLY,
        allowNull: false,
    },
    Received_date:{
        type: DataTypes.DATEONLY,
        allowNull: false
    },
    verifyMode:{
        type: DataTypes.STRING,
        allowNull: false
    }
},{
    tableName: 'monitordatatbl',
    timestamps: false   
})

export default MonitorData;