import {
    createOdPass,
    getHistoryOfOdPass
} from '../controller/odPass.controller.js'
import { Router } from 'express';

const router = Router();

router.route('/apply').post(createOdPass);
router.route('/history').get(getHistoryOfOdPass);

export default router;