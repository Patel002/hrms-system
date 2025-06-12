import {
    punchAttendance,
    getAttendance,
    getPunchDurations
} from '../controller/attendance.controller.js';
import { Router } from 'express';

const router = Router();

router.route('/punch').post(punchAttendance);
router.route('/list').get(getAttendance);
router.route('/day-duration/:empId').get(getPunchDurations);

export default router;