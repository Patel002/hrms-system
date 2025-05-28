import {
    punchAttendance
} from '../controller/attendance.controller.js';
import { Router } from 'express';

const router = Router();

router.route('/punch').post(punchAttendance);

export default router;