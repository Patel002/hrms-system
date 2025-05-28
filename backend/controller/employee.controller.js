import {
    Employee,
    Department,
    Company
} from "../utils/join.js";
import crypto from 'crypto';
import jwt from 'jsonwebtoken';

const loginEmployee = async (req, res) => {
    try {
        const { em_username, em_password } = req.body;

        if (!em_username || !em_password) {
            return res.status(400).json({ message: "Username and password are required" });
        }

        const hashedPassword = crypto.createHash('sha1').update(em_password).digest('hex');

        const employee = await Employee.findOne({
            where: {
                em_username: em_username,
                em_password: hashedPassword
            },
            include: [
                { model: Department, attributes: ['dep_name'] },
                { model: Company, attributes: ['comp_fname','comp_id'] }
            ]
        });

        // console.log("department", employee.department.dep_name);
        // console.log("company", employee.company.comp_fname);

            if (!employee) {
            return res.status(401).json({ message: "Invalid credentials" });
        }
    
       const supervisedEmployees = await Employee.findOne({
            where: {
                supervisor_id: employee.em_id
            }
        });

        console.log("this is supervised employees",supervisedEmployees);

        const isSupervisor = supervisedEmployees !== null;
        console.log("Is this employee a supervisor for others?", isSupervisor);

        const token = jwt.sign(
            {
                em_id: employee.em_id,
                em_code: employee.em_code,
                em_username: employee.em_username,
                em_role: employee.em_role,
                isSupervisor,
                dep_name: employee.department?.dep_name,
                comp_fname: employee.company?.comp_fname,
                comp_id: employee.company?.comp_id
            },
            "this is a secret key of !@#$%^&*()_+-=[]{};':\"|\\<>/?~`",
            { expiresIn: '1d' }
        );
        
        // console.log("token", token);

        return res.status(200).json({ message: "Login successful", token, data: employee });

    } catch (error) {
        console.log(error);
        return res.status(500).json({message: "Internal Server Error"});
    }
}

export {
    loginEmployee
}