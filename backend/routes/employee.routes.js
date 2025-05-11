import {
    loginEmployee
} from "../controller/employee.controller.js";
import { Router } from "express";

const router = Router();

router.route('/login').post(loginEmployee);

export default router;