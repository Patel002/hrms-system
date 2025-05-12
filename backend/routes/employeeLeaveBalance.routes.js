import{
    getEmployeeLeaveBalance
} from '../controller/employeeLeaveBalance.controller.js';
import { Router } from 'express';

const router = Router();

router.route('/balance/:em_code').get(getEmployeeLeaveBalance);

export default router;