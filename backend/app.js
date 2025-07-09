import express from 'express';
import cors from 'cors';
// import path from 'path';
// import fs from 'fs';

const app = express();
app.use(cors());

app.use(express.json());

app.use(express.urlencoded({
    limit: '50mb',
    extended: true
}));

app.use((err, req, res, next) => {
    if(err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ message: 'File size limit exceeded by 10Mb' });
    }
    console.log(err.stack);
      res.status(500).json({ message: 'Something went wrong' });
})

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
import payslipRoutes from './routes/payslip.routes.js';

app.use("/api/holiday",holidayRoutes);
app.use("/api/employee",employeeRoutes);
app.use("/api/emp-leave",leaveRoutes);
app.use("/api/leave-type",leaveTypesRoutes);
app.use("/api/balance",employeeLeaveBalanceRoutes);
app.use("/api/attendance",attendanceRoutes);
app.use("/api/od-pass",odPassRoutes);
app.use("/api/month-trans",monthTransRoutes);
app.use("/api/payslip",payslipRoutes);

export {app};