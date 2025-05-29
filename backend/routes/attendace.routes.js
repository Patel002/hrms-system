import {
    punchAttendance,
    getAttendance
} from '../controller/attendance.controller.js';
import { Router } from 'express';

const router = Router();

router.route('/punch').post(punchAttendance);
router.route('/list').get(getAttendance);

export default router;