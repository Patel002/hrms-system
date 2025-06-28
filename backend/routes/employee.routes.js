import {
    loginEmployee,
    getEmployeeDetails,
    updateEmployeeDetails,
    getFileAttachment
} from "../controller/employee.controller.js";
import { upload } from "../middleware/multer.middleware.js";
import { Router } from "express";

const router = Router();

router.route('/login').post(loginEmployee);
router.route('/info/:em_id').get(getEmployeeDetails);
router.route('/update/:em_id').patch(upload.single('em_image'),updateEmployeeDetails);
router.route('/attachment/:filename').get(getFileAttachment);


export default router;