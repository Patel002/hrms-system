import Attendance from "../model/attendance.model.js";
import { DateTime } from "luxon";
const punchAttendance = async(req, res) => {
    try {
        const { emp_id, comp_id, punch_place, punch_remark, punch_img, latitude, longitude, created_by } = req.body;

       const istNow = DateTime.now().setZone('Asia/Kolkata');
       const punchDate = istNow.toISODate(); 
       const punchTime = istNow.toFormat('HH:mm:ss'); 
       const createdAt = istNow.toJSDate();
       
       console.log("Current IST Date and Time:", istNow);
       console.log("Punch Date:", punchDate);
       console.log("Punch Time:", punchTime);
       console.log("Created At:", createdAt);

        if (!emp_id || !comp_id || !punch_place || !punch_img || !latitude || !longitude || !created_by) {
            return res.status(400).json({ message: "All fields are required" });
        }

        const newAttendance = await Attendance.create({
            emp_id,
            comp_id,
            punch_date: punchDate,
            punch_time: punchTime,
            punch_place,
            punchtype: 'OUTSTATION1',
            punch_remark,
            punch_img,
            latitude,
            longitude,
            created_by,
            created_at: createdAt
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

export {
    punchAttendance
}