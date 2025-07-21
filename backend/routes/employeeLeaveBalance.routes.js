import{
    getEmployeeLeaveBalance
} from '../controller/employeeLeaveBalance.controller.js';
import { Router } from 'express';

const router = Router();

router.route('/balance/:emp_id').get(getEmployeeLeaveBalance);

export default router;