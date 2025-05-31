import Attendance from "../model/attendance.model.js";
import { DateTime } from "luxon";
import { Op } from "sequelize";

const punchAttendance = async(req, res) => {
    try {
        const { emp_id, comp_id, punchtype, punch_place, punch_remark, punch_img, latitude, longitude, created_by } = req.body;

       const istNow = DateTime.now().setZone('Asia/Kolkata');
       const punchDate = istNow.toISODate(); 
       const punchTime = istNow.toFormat('HH:mm:ss'); 
       const createdAtIst = istNow.toISO();
       
       console.log("Current IST Date and Time:", istNow);
       console.log("Punch Date:", punchDate);
       console.log("Punch Time:", punchTime);
       console.log("Created At:", createdAtIst);

        if (!emp_id || !comp_id || !punch_place || !punch_img || !latitude || !longitude || !created_by) {
            return res.status(400).json({ message: "All fields are required" });
        }

        const lastPunchIn = await Attendance.findOne({
        where: {
            emp_id,
            punchtype: 'OUTSTATION1'
        },
        order: [['created_at', 'DESC']]
        });

        const punchOutExists = lastPunchIn
        ? await Attendance.findOne({
            where: {
                emp_id,
                punchtype: 'OUTSTATION2',
                created_at: { [Op.gt]: lastPunchIn.created_at }
            }
            })
        : null;

        if (punchtype === 'OUTSTATION1') {
        if (lastPunchIn && !punchOutExists) {
            return res.status(400).json({ message: "Already punched in without punching out." });
        }
        }

        if (punchtype === 'OUTSTATION2') {
        if (!lastPunchIn) {
            return res.status(400).json({ message: "Cannot punch out without punching in." });
        }
        if (punchOutExists) {
            return res.status(400).json({ message: "Already punched out for your last punch in." });
        }
        }

        const newAttendance = await Attendance.create({
            emp_id,
            comp_id,
            punch_date: punchDate,
            punch_time: punchTime,
            punch_place,
            punchtype,
            punch_remark,
            punch_img,
            latitude,
            longitude,
            created_by,
            created_at: createdAtIst
        });

        console.log("Attendance recorded:", newAttendance);

        res.status(201).json({
            message: "Attendance recorded successfully",
            data: newAttendance
        });
    } catch (error) {
        console.error("Error recording attendance:", error);
        res.status(500).json({
            message: "Error recording attendance",
            error: error.message
        });
    }
}

const getAttendance = async (req, res) => {
    const { emp_id, punch_date  } = req.query;
    if (!emp_id) {
        return res.status(400).json({ message: "Employee ID is required" });
    }
    try {
        const attendances = await Attendance.findAll({
            where: {
                emp_id: emp_id,
                punch_date: punch_date
            }
        });
        res.status(200).json({ message: "Attendances fetched successfully", data: attendances });
    } catch (error) {
        console.error("Error fetching attendances:", error);
        res.status(500).json({
            message: "Error fetching attendances",
            error: error.message
        });
    }
}

export {
    punchAttendance,
    getAttendance
}