import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json({
    limit: '50mb'
}));
app.use(express.urlencoded({
    limit: '50mb',
    extended: true
}));

import employeeRoutes from './routes/employee.routes.js';
import holidayRoutes from './routes/holiday.routes.js';
import leaveRoutes from './routes/employeeLeave.routes.js';
import leaveTypesRoutes from './routes/leaveTypes.routes.js';
import employeeLeaveBalanceRoutes from './routes/employeeLeaveBalance.routes.js';
import attendanceRoutes from './routes/attendace.routes.js';

app.use("/api/holiday",holidayRoutes);
app.use("/api/employee",employeeRoutes);
app.use("/api/emp-leave",leaveRoutes);
app.use("/api/leave-type",leaveTypesRoutes);
app.use("/api/balance",employeeLeaveBalanceRoutes);
app.use("/api/attendance",attendanceRoutes);

export {app};