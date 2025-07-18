import {
    createOdPass,
    getHistoryOfOdPass,
    updateOdPassApplication,
    getLeaveRequestsBySupervisor,
    approveRejectOd
} from '../controller/odPass.controller.js'
import { authenticateUser } from '../middleware/auth.middleware.js';
import { Router } from 'express';

const router = Router();

router.route('/apply').post(createOdPass);
router.route('/history').get(getHistoryOfOdPass);
router.route('/update/:id').patch(updateOdPassApplication);
router.route('/list/:status').get(authenticateUser,getLeaveRequestsBySupervisor);
router.route('/approve-reject/:id').patch(authenticateUser,approveRejectOd);

export default router;