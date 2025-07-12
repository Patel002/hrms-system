import {
    punchAttendance,
    getAttendance,
    getPunchDurations,
    getAttendanceSummary
} from '../controller/attendance.controller.js';
import { Router } from 'express';

const router = Router();

router.route('/punch').post(punchAttendance);
router.route('/list').get(getAttendance);
router.route('/day-duration/:empId').get(getPunchDurations);
router.route('/summary/:empId').get(getAttendanceSummary);

export default router;