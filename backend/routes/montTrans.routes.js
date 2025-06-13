import {
    getMonthTrans
} from '../controller/monthTrans.controller.js';
import { Router } from 'express';

const router = Router();

router.route('/list/:emp_id').get(getMonthTrans);

export default router;