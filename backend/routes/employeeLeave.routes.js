import { Router } from "express";
import {
    createLeave, getLeavesByStatusForEmployee ,updateLeaveApplication,approveRejectLeave,getLeaveRequestsBySupervisor,getLeaves
} from "../controller/employeeLeave.controller.js";
import {upload} from '../middleware/multer.middleware.js';
import {authenticateUser} from '../middleware/auth.middleware.js'

const router = Router();

router.route('/leave').post(upload.single('leaveattachment'),createLeave);
router.route('/list').get(getLeavesByStatusForEmployee);
// router.route('/avalibaleLeaves').get(avalibaleLeaves);
// router.route('/attachment/:filename').get(getFileAttachment);
router.route('/update/:id').patch(upload.single('leaveattachment'),updateLeaveApplication);

router.route('/list/:status').get(authenticateUser,getLeaveRequestsBySupervisor);

router.route('/approve-reject/:id').patch(authenticateUser,approveRejectLeave);

router.route('/all-calendar-leaves').get(getLeaves);

export default router;
