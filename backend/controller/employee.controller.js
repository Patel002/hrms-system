import {
    Employee,
    Department,
    Company
} from "../utils/join.js";
import path from "path";
import fs from 'fs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';

    const loginEmployee = async (req, res) => {
        try {
            const { em_id, em_password } = req.body;

            if (!em_id || !em_password) {
                return res.status(400).json({ message: "Userid and password are required" });
            }

            const hashedPassword = crypto.createHash('sha1').update(em_password).digest('hex');

            const employee = await Employee.findOne({
                where: {
                    em_id: em_id,
                    em_password: hashedPassword
                },
                include: [
                    { model: Department, attributes: ['dep_name'] },
                    { model: Company, attributes: ['comp_fname'] }
                ]
            });

            // console.log("department", employee.department?.dep_name);
            // console.log("company", employee.company.comp_fname, employee.comp_id);

                if (!employee) {
                return res.status(401).json({ message: "Invalid credentials" });
            }
        
        const supervisedEmployees = await Employee.findOne({
                where: {
                    supervisor_id: employee.em_id
                }
            });

            // console.log("this is supervised employees",supervisedEmployees);

            const isSupervisor = supervisedEmployees !== null;
            console.log("Is this employee a supervisor for others?", isSupervisor);

            const payload =  {
                    em_id: employee.em_id,
                    em_code: employee.em_code,
                    em_username: employee.em_username,
                    first_name: employee.first_name,
                    em_role: employee.em_role,
                    isSupervisor,
                    dep_name: employee.department?.dep_name,
                    comp_fname: employee.company?.comp_fname,
                    comp_id: employee.comp_id
                };

            const token = jwt.sign(
               
                "this is a secret key of !@#$%^&*()_+-=[]{};':\"|\\<>/?~`",
                { expiresIn: '180d' }
            );
            
            console.log("token", token);

            return res.status(200).json({ message: "Login successful", token, data: employee });

        } catch (error) {
            console.log(error);
            return res.status(500).json({message: "Internal Server Error from employee login"});
        }
    }

const getEmployeeDetails = async(req, res) => {
    try {
        const { em_id } = req.params;

        const employee = await Employee.findOne({
            where: { em_id },
            include: [
                { model: Department, attributes: ['dep_name'] },
                { model: Company, attributes: ['comp_fname', 'comp_id'] }
            ]
        });

        if (!employee) {
            return res.status(404).json({ message: "Employee not found" });
        }

        // console.log("Employee details:", employee);

        return res.status(201).json({ message: "Employee details fetched successfully", data: employee });

    } catch (error) {
        console.log(error);
        return res.status(500).json({ message: "Internal Server Error" });
    }
}

const updateEmployeeDetails = async (req, res) => {
    const { em_id } = req.params;
    const updateData = req.body;

    try {
        const employee = await Employee.findOne({ where: { em_id } });

        if(!employee ) {
            return res.status(404).json({ message: "Employee not found" });
        }  
        
        const { department, company, ...allowedUpdates } = updateData;

        if (req.file?.filename) {
        allowedUpdates.em_image = req.file.filename;
        }

        allowedUpdates.updated_at = new Date();
        allowedUpdates.updated_by = employee.em_id;
        
        const updatedEmployee = await employee.update(allowedUpdates);


        // console.log("Updated Employee:", updatedEmployee);

        const imageUrl = req.file
        ? `${req.protocol}://${req.get('host')}/uploads/profileImage/${req.file.filename}`
        : employee.em_image;

        // console.log("Image URL:", imageUrl);

        return res.status(200).json({ message: "Employee details updated successfully", data: updatedEmployee, imageUrl });
        
    } catch (error) {
        console.log(error);
        return res.status(500).json({ message: "Internal Server Error" });
        
    }

}

const getFileAttachment = async(req, res) => {
    const filename = req.params.filename;   
    const filePath = path.resolve('..','uploads','profileImage', filename);

    fs.access(filePath, fs.constants.F_OK, (err) => {
        if (err) {
            res.status(404).send('File not found');
        } 
        res.sendFile(filePath);
    });

}

export {
    loginEmployee,
    getEmployeeDetails,
    updateEmployeeDetails,
    getFileAttachment
}