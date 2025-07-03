import express from 'express';
import cors from 'cors';
// import path from 'path';
// import fs from 'fs';

const app = express();
app.use(cors());
app.use(express.json({
    limit: '50mb'
}));

app.use(express.urlencoded({
    limit: '50mb',
    extended: true
}));

// const uploadDir = path.join(process.cwd(), 'uploads', 'profileImage');
// if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });


// app.use('/uploads', express.static(path.join(process.cwd(),'uploads')));

import employeeRoutes from './routes/employee.routes.js';
import holidayRoutes from './routes/holiday.routes.js';
import leaveRoutes from './routes/employeeLeave.routes.js';
import leaveTypesRoutes from './routes/leaveTypes.routes.js';
import employeeLeaveBalanceRoutes from './routes/employeeLeaveBalance.routes.js';
import attendanceRoutes from './routes/attendace.routes.js';
import odPassRoutes from './routes/odPass.routes.js';
import monthTransRoutes from './routes/montTrans.routes.js';

app.use("/api/holiday",holidayRoutes);
app.use("/api/employee",employeeRoutes);
app.use("/api/emp-leave",leaveRoutes);
app.use("/api/leave-type",leaveTypesRoutes);
app.use("/api/balance",employeeLeaveBalanceRoutes);
app.use("/api/attendance",attendanceRoutes);
app.use("/api/od-pass",odPassRoutes);
app.use("/api/month-trans",monthTransRoutes);

export {app};