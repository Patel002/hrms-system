import {
    loginEmployee,
    getEmployeeDetails,
    updateEmployeeDetails
} from "../controller/employee.controller.js";
import { Router } from "express";

const router = Router();

router.route('/login').post(loginEmployee);
router.route('/info/:em_id').get(getEmployeeDetails);
router.route('/update/:em_id').patch(updateEmployeeDetails);

export default router;