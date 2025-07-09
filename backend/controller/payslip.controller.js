import PaySlip from "../model/payslip.model.js";

const getPaySlipInformation = async (req, res) => {
        const { emp_id, salarydate } = req.query;
        
        try {
            
            if(!emp_id) {
                return res.status(400).json({ message: "Employee ID is required" });
            }

            const payslip = await PaySlip.findOne({ 
                where: {    
                    emp_id,
                    // salarydate: salarydate
                } 
            });
            if (!payslip) {
                return res.status(404).json({ message: "Payslip not found" });
            }

            // console.log("Payslip information:", payslip);
            return res.status(200).json({ message: "Payslip information fetched successfully", data: [payslip] });

        } catch (error) {
            // console.log(error);
            return res.status(500).json({ message: "Internal server error from getting payslip" });
        }
}

export { getPaySlipInformation };