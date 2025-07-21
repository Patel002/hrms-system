import {
    getMonthTrans
} from '../controller/monthTrans.controller.js';
import { Router } from 'express';

const router = Router();

router.route('/list/:attcode').get(getMonthTrans);

export default router;