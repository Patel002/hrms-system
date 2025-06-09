import {
    createOdPass,
    getHistoryOfOdPass,
    updateOdPassApplication
} from '../controller/odPass.controller.js'
import { Router } from 'express';

const router = Router();

router.route('/apply').post(createOdPass);
router.route('/history').get(getHistoryOfOdPass);
router.route('/update/:id').patch(updateOdPassApplication);

export default router;